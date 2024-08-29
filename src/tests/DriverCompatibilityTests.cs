using System;
using MongoDB.Driver;
using MongoDB.Driver.Core.Clusters;
using NUnit.Framework;

[TestFixture]
class DriverCompatibilityTests
{
    [Test]
    public void Should_report_correct_cluster_type()
    {
        var connectionString = Environment.GetEnvironmentVariable("MongoDBConnectionString");
        TestContext.WriteLine("ConnectionString: " + connectionString);

        var client = new MongoClient(connectionString);

        //do a fake call to make sure that cluster details is fetched
        client.ListDatabases();

        TestContext.WriteLine("State: " + client.Cluster.Description.State);
        TestContext.WriteLine("Type: " + client.Cluster.Description.Type);
        TestContext.WriteLine("ReplicaSetName: " + client.Cluster.Settings.ReplicaSetName);

        Assert.That(client.Cluster.Description.Type, Is.EqualTo(ClusterType.ReplicaSet));
        Assert.That(client.Cluster.Settings.ReplicaSetName, Is.EqualTo("tr0"));
    }
}