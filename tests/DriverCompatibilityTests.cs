using System;
using System.Threading.Tasks;
using MongoDB.Driver;
using MongoDB.Driver.Core.Clusters;
using NUnit.Framework;

[TestFixture]
class DriverCompatibilityTests
{
    [Test]
    public async Task Should_report_correct_cluster_type()
    {
        var containerConnectionString = Environment.GetEnvironmentVariable("MongoDBConnectionString");

        var client = new MongoClient(containerConnectionString);

        using (var session = await client.StartSessionAsync())
        {
            Assert.AreEqual(client.Cluster.Description.Type, ClusterType.ReplicaSet);
        }
    }
}