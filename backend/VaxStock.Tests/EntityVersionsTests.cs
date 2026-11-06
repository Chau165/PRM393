using Microsoft.AspNetCore.Http;
using VaxStock.Api.Infrastructure;
using VaxStock.Business.Exceptions;
using Xunit;

namespace VaxStock.Tests;

public sealed class EntityVersionsTests
{
    [Fact]
    public void Missing_version_requires_precondition()
    {
        var context = new DefaultHttpContext();
        var error = Assert.Throws<ManagementException>(() => EntityVersions.Require(context.Request));
        Assert.Equal(428, error.Status);
    }

    [Theory]
    [InlineData("*")]
    [InlineData("W/\"AAAAAAAAAAE=\"")]
    [InlineData("\"AA==\"")]
    [InlineData("\" AAAAAAAAAAE=\"")]
    [InlineData("\"AAAAAAAAAAE=\",\"AAAAAAAAAAE=\"")]
    public void Invalid_or_noncanonical_versions_are_rejected(string value)
    {
        var context = new DefaultHttpContext();
        context.Request.Headers.IfMatch = value;
        var error = Assert.Throws<ManagementException>(() => EntityVersions.Require(context.Request));
        Assert.Equal(400, error.Status);
    }

    [Fact]
    public void Strong_version_roundtrips()
    {
        var context = new DefaultHttpContext();
        EntityVersions.Set(context.Response, "AAAAAAAAAAE=");
        context.Request.Headers.IfMatch = context.Response.Headers.ETag;
        Assert.Equal(Convert.FromBase64String("AAAAAAAAAAE="), EntityVersions.Require(context.Request));
    }
}
