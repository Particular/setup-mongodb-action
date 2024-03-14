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

        TestContext.WriteLine("ClusterId: " + client.Cluster.Description.ClusterId);
        TestContext.WriteLine("State: " + client.Cluster.Description.State);
        TestContext.WriteLine("Type: " + client.Cluster.Description.Type);
        TestContext.WriteLine("IsCompatibleWithDriver: " + client.Cluster.Description.IsCompatibleWithDriver);
        TestContext.WriteLine("ServerCount: " + client.Cluster.Description.Servers.Count);
        TestContext.WriteLine("ReplicaSetName: " + client.Cluster.Settings.ReplicaSetName);

        Assert.AreEqual(ClusterType.ReplicaSet, client.Cluster.Description.Type);
    }
}