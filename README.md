# setup-mongodb-action

Runs MongoDB for a GitHub Actions workflow

## Usage

See [action.yml](action.yml)

```yaml
steps:
  - name: Install MongoDB
    uses: Particular/setup-mongodb-action@v1.2.0
    with:
      connection-string-name: <my connection string name>
      mongodb-version: <mongodb version string>
      mongodb-replica-set: <replicasetname>
      mongodb-port: <portnumber>
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).
