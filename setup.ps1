param (
    [string]$ContainerName,
    [string]$ConnectionStringName,
    [string]$MongoDbVersion = "7.0.39",
    [string]$MongoDbPort = "27017",
    [string]$ReplicaSet = ""
)

$ErrorActionPreference = 'Stop'

# Require setup-wsl-action to have run first — it provisions WSL/Docker and exports
# the WslTools module at WSL_TOOLS_MODULE_PATH.
if (-not $Env:WSL_TOOLS_MODULE_PATH) {
    throw "This action requires Particular/setup-wsl-action to run first — it provisions WSL/Docker and exports the WslTools module at WSL_TOOLS_MODULE_PATH."
}
Import-Module $Env:WSL_TOOLS_MODULE_PATH -Force

function Export-Env {
    param([string]$Name, [string]$Value)
    "$Name=$Value" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
}

$runnerOs = $Env:RUNNER_OS ?? "Linux"

# Validate the version — it's user-controlled and interpolated into docker commands.
# Docker tags: max 128 chars, alphanumeric + _ . -, must start with alphanumeric or _.
if ($MongoDbVersion -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$') {
    throw "mongodb-version must be a valid Docker image tag (alphanumeric, underscore, period, hyphen; max 128 chars). Got: $MongoDbVersion"
}

$port = 0
if (-not [int]::TryParse($MongoDbPort, [ref]$port) -or $port -lt 1 -or $port -gt 65535) {
    throw "mongodb-port must be a valid TCP port (1-65535). Got: $MongoDbPort"
}

# Validate the replica set name — it's user-controlled and interpolated into docker
# and mongosh commands. Restrict to the characters MongoDB accepts in replica set
# names so the value can never break out of the command line.
if ($ReplicaSet -and $ReplicaSet -notmatch '^[A-Za-z0-9_.-]{1,128}$') {
    throw "mongodb-replica-set contains unsupported characters. Got: $ReplicaSet"
}

$image = "mongo:$MongoDbVersion"
# Advertised to clients via the connection string and replica set member host.
$ipAddress = "127.0.0.1"

# Cap the WiredTiger cache instead of letting mongod take the default (50% of container
# RAM). On Windows the container runs inside the WSL2 VM that setup-wsl-action provisions
# with a 4GB memory cap; the default cache plus connection churn leaves no headroom and
# mongod gets OOM-killed mid-suite, which surfaces as EndOfStreamException in clients.
# 1GB is plenty for test-sized datasets on every runner.
$WiredTigerCacheSizeGB = 1

# Ubuntu's default ulimit -n is 1024 and dockerd inside WSL inherits it, so containers get
# a 1024 fd limit. The acceptance-suite load (hundreds of pooled connections plus one
# WiredTiger data/index file per collection) exhausts that and mongod fails with
# "24: Too many open files" and dies, dropping every client connection. Raise the limit
# explicitly; WSL's hard limit is 1048576. Harmless on Linux runners, where the daemon
# already runs with a high limit.
$ContainerNofileLimit = "1048576:1048576"

if ($runnerOs -eq "Linux") {
    Write-Output "Running MongoDB in container $ContainerName using Docker"

    $dockerArgs = @("--port", "$port", "--wiredTigerCacheSizeGB", "$WiredTigerCacheSizeGB")
    if ($ReplicaSet) {
        $dockerArgs += @("--replSet", $ReplicaSet)
    }

    docker run --name $ContainerName --detach --restart unless-stopped --ulimit "nofile=$ContainerNofileLimit" --publish "${port}:${port}" $image @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start MongoDB container"
    }
}
elseif ($runnerOs -eq "Windows") {
    Write-Output "Running MongoDB in container $ContainerName using WSL"

    # WSL and Docker were provisioned by setup-wsl-action. Read the distribution
    # and the WSL VM IP from the environment it exported.
    $wslDistribution = $Env:WSL_DISTRIBUTION
    $ipAddress = $Env:WSL_IP

    if (-not $ipAddress) {
        throw "WSL_IP is not set. Run Particular/setup-wsl-action before this action."
    }
    Write-Output "WSL address: $ipAddress"

    $runCommand = "docker run --name $ContainerName --detach --restart unless-stopped --ulimit nofile=$ContainerNofileLimit --publish ${port}:${port} $image --port $port --wiredTigerCacheSizeGB $WiredTigerCacheSizeGB"
    if ($ReplicaSet) {
        $runCommand += " --replSet $ReplicaSet"
    }

    Invoke-Wsl -Distribution $wslDistribution -CheckExitCode -Command $runCommand
    Invoke-Wsl -Distribution $wslDistribution -Command "docker ps --filter name=$ContainerName"
}
else {
    throw "$runnerOs not supported"
}

Write-Output "::group::Waiting for MongoDB to be ready"
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    Write-Output "Attempt $i/30 to check MongoDB readiness..."

    if ($runnerOs -eq "Linux") {
        $serverStatus = (docker exec $ContainerName mongosh "mongodb://127.0.0.1:$port" --eval "db.serverStatus().ok" --quiet 2>$null) -join "`n"
        $ok = ($LASTEXITCODE -eq 0) -and ($serverStatus -match '1')
    }
    else {
        $serverStatus = (Invoke-Wsl -Distribution $wslDistribution -Command "docker exec $ContainerName mongosh mongodb://127.0.0.1:$port --eval 'db.serverStatus().ok' --quiet 2>/dev/null") -join "`n"
        $ok = ($LASTEXITCODE -eq 0) -and ($serverStatus -match '1')
    }

    if ($ok) {
        Write-Output "  - MongoDB is ready"
        $ready = $true
        break
    }

    Write-Output "  - Not ready yet, sleeping for 5s"
    Start-Sleep -Seconds 5
}
Write-Output "::endgroup::"

if (-not $ready) {
    throw "MongoDB did not become ready within 150s."
}

if ($ReplicaSet) {
    Write-Output "::group::Initializing replica set $ReplicaSet"

    # Write the initiate script to a file and copy it into the container, then run it as a
    # script file. Inlining it via --eval would need shell quoting that breaks in the
    # bash -c wrapper WSL interop uses, so we keep the script out of the command line.
    $rsScript = "rs.initiate({ _id: '$ReplicaSet', members: [ { _id: 0, host: '${ipAddress}:${port}' } ] });"
    $hostScriptPath = Join-Path $Env:RUNNER_TEMP "init-replica-set.js"
    [IO.File]::WriteAllText($hostScriptPath, $rsScript)
    $containerScriptPath = "/tmp/init-replica-set.js"

    if ($runnerOs -eq "Linux") {
        docker cp $hostScriptPath "${ContainerName}:${containerScriptPath}"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy replica set init script into the container"
        }
        docker exec $ContainerName mongosh "mongodb://127.0.0.1:$port" $containerScriptPath --quiet
        if ($LASTEXITCODE -ne 0) {
            throw "Replica set initialization failed"
        }
    }
    else {
        # ConvertTo-WslPath maps the Windows path to /mnt/<drive>/ for Docker inside WSL.
        $wslScriptPath = ConvertTo-WslPath -WindowsPath $hostScriptPath
        Invoke-Wsl -Distribution $wslDistribution -CheckExitCode -Command "docker cp '$wslScriptPath' '${ContainerName}:${containerScriptPath}'"
        Invoke-Wsl -Distribution $wslDistribution -CheckExitCode -Command "docker exec $ContainerName mongosh mongodb://127.0.0.1:$port $containerScriptPath --quiet"
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Replica set initialization failed"
    }

    # A single-node replica set elects itself primary shortly after initiate.
    # Wait for that so consumers never observe a topology without a primary.
    $primary = $false
    for ($i = 1; $i -le 12; $i++) {
        Start-Sleep -Seconds 5
        Write-Output "Checking for primary $i/12..."

        if ($runnerOs -eq "Linux") {
            $hello = (docker exec $ContainerName mongosh "mongodb://127.0.0.1:$port" --eval "db.hello().isWritablePrimary" --quiet 2>$null) -join "`n"
            $isPrimary = ($LASTEXITCODE -eq 0) -and ($hello -match 'true')
        }
        else {
            $hello = (Invoke-Wsl -Distribution $wslDistribution -Command "docker exec $ContainerName mongosh mongodb://127.0.0.1:$port --eval 'db.hello().isWritablePrimary' --quiet 2>/dev/null") -join "`n"
            $isPrimary = ($LASTEXITCODE -eq 0) -and ($hello -match 'true')
        }

        if ($isPrimary) {
            Write-Output "  - Primary elected"
            $primary = $true
            break
        }
    }

    if (-not $primary) {
        throw "Replica set $ReplicaSet did not elect a primary within 60 seconds."
    }

    Write-Output "::endgroup::"
}

# A mongosh shim on PATH gives consumers one command on both platforms. On
# Windows the shim routes through `bash -c` with each argument quoted: wsl.exe
# re-parses argv as a shell command line, so an unquoted --eval script with
# parentheses would cause a syntax error.
Write-Output "Creating mongosh forwarding script"
$shimDir = Join-Path $Env:RUNNER_TEMP "mongodb-shim"
New-Item -ItemType Directory -Force -Path $shimDir | Out-Null

if ($runnerOs -eq "Linux") {
    $mongoshPath = Join-Path $shimDir "mongosh"
    Set-Content -Path $mongoshPath -Value "#!/bin/bash`ndocker exec -i $ContainerName mongosh `"`$@`"" -Encoding ASCII
    & chmod +x $mongoshPath
}
else {
    $mongoshPath = Join-Path $shimDir "mongosh.ps1"
    Set-Content -Path $mongoshPath -Encoding ASCII -Value @"
`$quoted = (`$args | ForEach-Object { "'" + (`$_ -replace "'", "'\''") + "'" }) -join ' '
`$command = "docker exec -i $ContainerName mongosh `$quoted"
`$input | wsl.exe --distribution `$env:WSL_DISTRIBUTION --user root -- bash -c `$command
"@
}

Write-Output "Adding mongosh shim to PATH"
$shimDir | Out-File -FilePath $Env:GITHUB_PATH -Encoding utf8 -Append
# GITHUB_PATH only affects subsequent steps; set in current process too.
if ($runnerOs -eq "Linux") {
    $Env:PATH = "$shimDir`:$Env:PATH"
} else {
    $Env:PATH = "$shimDir;$Env:PATH"
}

$connectionString = "mongodb://${ipAddress}:${port}"
if ($ReplicaSet) {
    $connectionString = "$connectionString/?replicaSet=$ReplicaSet"
}

Write-Output "Setting environment variable $ConnectionStringName to MongoDB connection string..."
Export-Env -Name $ConnectionStringName -Value $connectionString
