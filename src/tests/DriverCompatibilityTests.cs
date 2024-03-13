using System;
using System.Threading.Tasks;
using MongoDB.Bson;
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

        TestContext.WriteLine(client.Cluster.Description.ToJson());
        Assert.AreEqual(client.Cluster.Description.Type, ClusterType.ReplicaSet);
    }
}