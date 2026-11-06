namespace VaxStock.Api.Security;
public sealed class JwtSettings
{
    public string Issuer { get; set; } = "VaxStock.Api";
    public string Audience { get; set; } = "VaxStock.Flutter";
    public string SigningKey { get; set; } = string.Empty;
    public int LifetimeSeconds { get; set; } = 900;
    public void Validate()
    {
        if (string.IsNullOrWhiteSpace(Issuer) || string.IsNullOrWhiteSpace(Audience)
            || System.Text.Encoding.UTF8.GetByteCount(SigningKey) < 32 || LifetimeSeconds is < 5 or > 3600)
            throw new InvalidOperationException("Configure Jwt issuer/audience, a signing key of at least 32 bytes, and lifetime 5–3600 seconds using local configuration or environment variables.");
    }
}
