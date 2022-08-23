# setup-mongodb-action

Runs MongoDB for a GitHub Actions workflow

## Usage

See [action.yml](action.yml)

```yaml
steps:
  - name: Install SQL Server
    uses: Particular/setup-mongodb-action@v1.0.0
    with:
      connection-string-name: <my connection string name>
      mongodb-replica-set: <replicasetname>
      mongodb-port: <portnumber>
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).