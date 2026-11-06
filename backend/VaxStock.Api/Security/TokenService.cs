using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Security;

public sealed class TokenService(JwtSettings settings, TimeProvider clock) : ITokenService
{
    public TokenResult Issue(TokenSubject subject)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var jwt = new JwtSecurityToken(settings.Issuer, settings.Audience,
        [
            new Claim(JwtRegisteredClaimNames.Sub, subject.Id.ToString(CultureInfo.InvariantCulture)),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim("role", subject.Role),
            new Claim("authVersion", subject.AuthVersion.ToString(CultureInfo.InvariantCulture))
        ], notBefore: now, expires: now.AddSeconds(settings.LifetimeSeconds),
        signingCredentials: new(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SigningKey)), SecurityAlgorithms.HmacSha256));
        return new(new JwtSecurityTokenHandler().WriteToken(jwt), settings.LifetimeSeconds);
    }
}
