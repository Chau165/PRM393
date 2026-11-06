using VaxStock.Business.Models;
using Xunit;
namespace VaxStock.Tests;

public sealed class VaccineCalendarTests
{
    [Theory]
    [InlineData(-1,"Expired")]
    [InlineData(0,"Expired")]
    [InlineData(1,"NearExpiry")]
    [InlineData(30,"NearExpiry")]
    [InlineData(31,"Valid")]
    public void Expiry_boundaries_are_explicit(int offset,string expected)
    {
        var today=new DateOnly(2026,11,6);
        Assert.Equal(expected,VaccineCalendar.ExpiryStatus(today.AddDays(offset),today));
    }
    [Theory]
    [InlineData("2026-11-06T16:59:59Z",6)]
    [InlineData("2026-11-06T17:00:00Z",7)]
    public void Business_date_rolls_at_vietnam_midnight(string utc,int day)=>
        Assert.Equal(new DateOnly(2026,11,day),VaccineCalendar.Today(new Clock(DateTimeOffset.Parse(utc))));
    private sealed class Clock(DateTimeOffset now):TimeProvider
    {
        public override DateTimeOffset GetUtcNow()=>now;
    }
}
