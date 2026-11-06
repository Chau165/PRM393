using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using VaxStock.Business.Interfaces;
namespace VaxStock.Api.Security;

public sealed class PasswordService : IPasswordService
{
    private readonly PasswordHasher<object> _hasher = new();
    private readonly object _subject = new();
    private readonly string _dummyHash;
    public PasswordService() => _dummyHash = Hash(Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
    public string Hash(string password) => _hasher.HashPassword(_subject, password);
    public bool Verify(string hash, string password)
    {
        try
        {
            return _hasher.VerifyHashedPassword(_subject,
                string.IsNullOrEmpty(hash) ? _dummyHash : hash, password) != PasswordVerificationResult.Failed
                && !string.IsNullOrEmpty(hash);
        }
        catch (FormatException) { return false; }
    }
}
