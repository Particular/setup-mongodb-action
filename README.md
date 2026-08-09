# setup-mongodb-action

This action sets up a MongoDB server for a GitHub Actions workflow and tears it down when the job ends.

## Prerequisites

This action does not provision WSL or Docker itself. On **Windows** runners it requires [setup-wsl-action](https://github.com/Particular/setup-wsl-action) to run **first** in the same job. That action provisions WSL2 and Docker, keeps the instance alive, and exports the `WSL_DISTRIBUTION`, `WSL_IP`, and `WSL_TOOLS_MODULE_PATH` environment variables this action relies on. On **Linux** runners setup-wsl-action is a no-op but should still be included so the workflow is uniform.

If setup-wsl-action has not run, the action fails fast with a clear error.

## Usage

See [action.yml](action.yml)

```yaml
steps:
- name: Setup WSL
  uses: Particular/setup-wsl-action@v1
- name: Setup MongoDB
  uses: Particular/setup-mongodb-action@v1.0.0
  with:
    connection-string-name: <my connection string name>
    mongodb-replica-set: <replica set name>
    mongodb-version: <mongodb version tag>
    mongodb-port: <port number>
```

`connection-string-name` defaults to `MongoDBConnectionString`. `mongodb-version` defaults to `7.0.6`, `mongodb-port` to `27017`, and `mongodb-replica-set` is empty when omitted.

The action writes the connection string to the environment variable named by `connection-string-name`. When a replica set is configured, it appends `?replicaSet=<name>` so drivers pick up the topology from the connection string alone.

On Linux runners the MongoDB container runs directly through Docker. On Windows runners the same MongoDB container runs inside WSL2 provisioned by [setup-wsl-action](https://github.com/Particular/setup-wsl-action), so both platforms behave identically.

The action also adds `mongosh` to the PATH of subsequent steps on both platforms. It forwards into the container, so scripts that call `mongosh` keep working unchanged on Windows and Linux.

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md).

## Development

Open the folder in Visual Studio Code. If you don't already have them, you will be prompted to install remote development extensions. After installing them, and re-opening the folder in a container, do the following:

Run the npm installation

```bash
npm install
```

When changing `index.mjs`, either run `npm run dev` beforehand, which will watch the file for changes and automatically compile it, or run `npm run prepare` afterwards.

## Testing

### With Node.js

To test the setup action, create an `.env.setup` file in the root directory with the following content

```ini
# Input overrides
INPUT_CONNECTION-STRING-NAME=MongoDBConnectionString
INPUT_MONGODB-VERSION=7.0.6
INPUT_MONGODB-PORT=27018
INPUT_MONGODB-REPLICA-SET=tr0

# Runner overrides
# Use LINUX to run on Linux, WINDOWS to run on Windows via WSL2
RUNNER_OS=LINUX
```

then execute the script

```bash
node -r dotenv/config dist/index.mjs dotenv_config_path=.env.setup
```

To test the cleanup action add an `.env.cleanup` file in the root directory with the following content

```ini
# State overrides
STATE_IsPost=true
STATE_ContainerName=nameOfPreviouslyCreatedContainer
```

```bash
node -r dotenv/config dist/index.mjs dotenv_config_path=.env.cleanup
```

### With PowerShell

To test the setup action set the required environment variables and execute `setup.ps1` with the desired parameters.

```bash
$Env:RUNNER_OS=Linux
.\setup.ps1 -ContainerName mongodb-test-1 -ConnectionStringName MongoDBConnectionString
```

To test the cleanup action set the required environment variables and execute `cleanup.ps1` with the desired parameters.

```bash
$Env:RUNNER_OS=Linux
.\cleanup.ps1 -ContainerName mongodb-test-1
```

> Running `setup.ps1`/`cleanup.ps1` directly requires `WSL_TOOLS_MODULE_PATH` to point at setup-wsl-action's `WslTools` module (set it by running setup-wsl-action first).
