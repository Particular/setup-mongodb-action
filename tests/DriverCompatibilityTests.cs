using System;
using System.Threading.Tasks;
using MongoDB.Driver;
using MongoDB.Driver.Core.Clusters;
using NUnit.Framework;

[TestFixture]
class DriverCompatibilityTests
{
    [Test]
    public async Task Should_not_have_duplicate_subscriptions()
    {
        var containerConnectionString = Environment.GetEnvironmentVariable("MongoDBConnectionString");

        var client = new MongoClient(containerConnectionString);

        using (var session = client.StartSession())
        {
            Assert.AreEqual(client.Cluster.Description.Type, ClusterType.ReplicaSet);
        }
    }
}