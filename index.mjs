import * as path from 'node:path';
import * as url from 'node:url';
import * as core from '@actions/core';
import * as exec from '@actions/exec';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

const setupPs1 = path.resolve(__dirname, '../setup.ps1');
const cleanupPs1 = path.resolve(__dirname, '../cleanup.ps1');

// Determine if this is the post action, and set it true so that
// the next time we're executed, it goes to the post action.
const isPost = core.getState('IsPost');
core.saveState('IsPost', true);

const connectionStringName = core.getInput('connection-string-name') || 'MongoDBConnectionString';
const mongoDbVersion = core.getInput('mongodb-version') || '7.0.6';
const mongoDbPort = core.getInput('mongodb-port') || '27017';
const replicaSet = core.getInput('mongodb-replica-set');

async function run() {
    try {
        if (!isPost) {
            console.log('Running setup action');

            const containerName = 'mongodb' + Math.round(10000000000 * Math.random());
            core.saveState('ContainerName', containerName);

            console.log(`containerName = ${containerName}`);
            console.log(`mongoDbVersion = ${mongoDbVersion}`);
            console.log(`mongoDbPort = ${mongoDbPort}`);
            console.log(`replicaSet = ${replicaSet}`);

            await exec.exec('pwsh', [
                '-File', setupPs1,
                '-ContainerName', containerName,
                '-ConnectionStringName', connectionStringName,
                '-MongoDbVersion', mongoDbVersion,
                '-MongoDbPort', mongoDbPort,
                '-ReplicaSet', replicaSet
            ]);
        } else {
            console.log('Running cleanup');

            const containerName = core.getState('ContainerName');

            await exec.exec('pwsh', [
                '-File', cleanupPs1,
                '-ContainerName', containerName,
            ]);
        }
    } catch (err) {
        core.setFailed(err);
        console.log(err);
    }
}

run();
