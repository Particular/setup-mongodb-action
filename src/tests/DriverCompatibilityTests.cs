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
        var containerConnectionString = Environment.GetEnvironmentVariable("MongoDBConnectionString");
        var client = new MongoClient(containerConnectionString);

        TestContext.WriteLine(client.Cluster.Description.ClusterId);
        TestContext.WriteLine(client.Cluster.Description.State);
        TestContext.WriteLine(client.Cluster.Description.Type);
        TestContext.WriteLine(client.Cluster.Description.IsCompatibleWithDriver);
        TestContext.WriteLine(client.Cluster.Description.Servers.Count);
        TestContext.WriteLine(client.Cluster.ToString());
        TestContext.WriteLine(client.Cluster.ClusterId);
        TestContext.WriteLine(client.Cluster.Settings.ReplicaSetName);

        Assert.AreEqual(client.Cluster.Description.Type, ClusterType.ReplicaSet);
    }
}