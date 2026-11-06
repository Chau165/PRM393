namespace VaxStock.Api.Models;

public sealed class AppUser
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
}
public sealed class Warehouse
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}
public sealed class WarehouseAssignment
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public int WarehouseId { get; set; }
}
public sealed class Organization
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string Kind { get; set; } = string.Empty;
}
public sealed class Vaccine
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int ManufacturerId { get; set; }
    public int DosesPerVial { get; set; }
    public int VialsPerPack { get; set; }
    public decimal StorageMin { get; set; }
    public decimal StorageMax { get; set; }
}
public sealed class VaccineBatch
{
    public int Id { get; set; }
    public int VaccineId { get; set; }
    public string BatchNo { get; set; } = string.Empty;
    public DateOnly? ManufacturedAt { get; set; }
    public DateOnly ExpiresAt { get; set; }
}
public sealed class Receipt
{
    public int Id { get; set; }
    public string DocumentNo { get; set; } = string.Empty;
    public int WarehouseId { get; set; }
    public int SupplierId { get; set; }
    public DateOnly DocumentDate { get; set; }
    public string Status { get; set; } = string.Empty;
    public int CreatedById { get; set; }
    public DateTimeOffset? PostedAt { get; set; }
}
public sealed class ReceiptDetail
{
    public int Id { get; set; }
    public int ReceiptId { get; set; }
    public int BatchId { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
}
public sealed class StockSegment
{
    public int Id { get; set; }
    public int ReceiptDetailId { get; set; }
    public int WarehouseId { get; set; }
    public string QualityStatus { get; set; } = string.Empty;
    public byte[] RowVersion { get; set; } = [];
}
public sealed class Issue
{
    public int Id { get; set; }
    public string DocumentNo { get; set; } = string.Empty;
    public int WarehouseId { get; set; }
    public int RecipientId { get; set; }
    public DateOnly DocumentDate { get; set; }
    public string Status { get; set; } = string.Empty;
    public int CreatedById { get; set; }
    public DateTimeOffset? PostedAt { get; set; }
}
public sealed class IssueDetail
{
    public int Id { get; set; }
    public int IssueId { get; set; }
    public int StockSegmentId { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
}
public sealed class StockReservation
{
    public int Id { get; set; }
    public int IssueDetailId { get; set; }
    public int Quantity { get; set; }
    public bool Active { get; set; }
}
public sealed class StockMovement
{
    public int Id { get; set; }
    public int StockSegmentId { get; set; }
    public int QuantityDelta { get; set; }
    public int? ReceiptDetailId { get; set; }
    public int? IssueDetailId { get; set; }
    public int? StockDispositionDetailId { get; set; }
    public DateOnly EffectiveDate { get; set; }
    public DateTimeOffset PostedAt { get; set; }
}
public sealed class QualityDecision
{
    public int Id { get; set; }
    public int StockSegmentId { get; set; }
    public int? IncidentId { get; set; }
    public int DecidedById { get; set; }
    public string Status { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public DateTimeOffset DecidedAt { get; set; }
}
public sealed class Incident
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public int WarehouseId { get; set; }
    public string Kind { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Status { get; set; } = "Open";
    public DateTimeOffset OccurredAt { get; set; }
    public DateTimeOffset ReportedAt { get; set; }
    public int ReportedById { get; set; }
    public DateTimeOffset? ClosedAt { get; set; }
    public int? ClosedById { get; set; }
    public string? Resolution { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
public sealed class IncidentStockSegment
{
    public int Id { get; set; }
    public int IncidentId { get; set; }
    public int StockSegmentId { get; set; }
    public DateTimeOffset BlockedAt { get; set; }
    public DateTimeOffset? ReleasedAt { get; set; }
    public int? ReleasedById { get; set; }
    public string? ReleaseReason { get; set; }
}
public sealed class StockDisposition
{
    public int Id { get; set; }
    public string DocumentNo { get; set; } = string.Empty;
    public int WarehouseId { get; set; }
    public string Kind { get; set; } = string.Empty;
    public int? SupplierId { get; set; }
    public int? IncidentId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateOnly DocumentDate { get; set; }
    public string Status { get; set; } = "Draft";
    public int CreatedById { get; set; }
    public int? ApprovedById { get; set; }
    public DateTimeOffset? ApprovedAt { get; set; }
    public DateTimeOffset? PostedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
public sealed class StockDispositionDetail
{
    public int Id { get; set; }
    public int StockDispositionId { get; set; }
    public int StockSegmentId { get; set; }
    public int Quantity { get; set; }
}
public sealed class TradeShipment
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Kind { get; set; } = string.Empty;
    public int PartnerId { get; set; }
    public string OriginCountry { get; set; } = string.Empty;
    public string DestinationCountry { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateOnly? ExpectedDate { get; set; }
}
public sealed class ShipmentDocumentLink
{
    public int Id { get; set; }
    public int TradeShipmentId { get; set; }
    public int? ReceiptId { get; set; }
    public int? IssueId { get; set; }
}
public sealed class AuditLog
{
    public int Id { get; set; }
    public int ActorId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public int EntityId { get; set; }
    public string Details { get; set; } = string.Empty;
    public DateTimeOffset OccurredAt { get; set; }
}
