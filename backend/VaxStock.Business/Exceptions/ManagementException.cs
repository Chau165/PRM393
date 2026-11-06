namespace VaxStock.Business.Exceptions;

public sealed class ManagementException(string code, string message, int status, int? existingBatchId = null) : Exception(message)
{
    public string Code { get; } = code;
    public int Status { get; } = status;
    public int? ExistingBatchId { get; } = existingBatchId;
}
