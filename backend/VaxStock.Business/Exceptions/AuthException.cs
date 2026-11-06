namespace VaxStock.Business.Exceptions;

public sealed class AuthException(string code, string message, int status) : Exception(message)
{
    public string Code { get; } = code;
    public int Status { get; } = status;
}
