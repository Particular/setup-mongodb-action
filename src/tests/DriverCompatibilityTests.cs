using System;
using System.Text.Json;
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

        TestContext.WriteLine(JsonSerializer.Serialize(client.Cluster.Description));
        Assert.AreEqual(client.Cluster.Description.Type, ClusterType.ReplicaSet);
    }
}