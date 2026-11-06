using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using VaxStock.Api.Contracts;
using VaxStock.Api.Infrastructure;
using VaxStock.Business.Interfaces;
using VaxStock.Business.Models;
namespace VaxStock.Api.Controllers;

[ApiController,Route("api/v1/batches"),Authorize]
public sealed class BatchesController(IBatchService batches):ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(int page=1,int pageSize=20,int? vaccineId=null,string? search=null,string? expiryStatus=null,
        DateOnly? expiresBefore=null,string sort="expiresAt",CancellationToken ct=default)
    {
        var result=await batches.ListAsync(new(page,pageSize,vaccineId,search,expiryStatus,expiresBefore,sort),ct);
        return Ok(new PageResponse<BatchResponse>(result.Items.Select(Map).ToArray(),result.Page,result.PageSize,result.TotalItems,result.TotalPages));
    }
    [HttpGet("{id:int:min(1)}")]
    public async Task<IActionResult> Get(int id,CancellationToken ct)
    {
        var result=await batches.GetAsync(id,ct);EntityVersions.Set(Response,result.Version);return Ok(Map(result));
    }
    [HttpPost]
    public async Task<IActionResult> Create(CreateBatchRequest request,CancellationToken ct)
    {
        var result=await batches.CreateAsync(new(Actor,request.VaccineId,request.BatchNo,request.ManufacturedAt,request.ExpiresAt),ct);
        EntityVersions.Set(Response,result.Version);return CreatedAtAction(nameof(Get),new {id=result.Id},Map(result));
    }
    [HttpPut("{id:int:min(1)}"),Authorize(Roles="Admin")]
    public async Task<IActionResult> Update(int id,UpdateBatchRequest request,CancellationToken ct)
    {
        var result=await batches.UpdateAsync(new(Actor,id,EntityVersions.Require(Request),request.ManufacturedAt,request.ExpiresAt),ct);
        EntityVersions.Set(Response,result.Version);return Ok(Map(result));
    }
    [HttpDelete("{id:int:min(1)}"),Authorize(Roles="Admin")]
    public async Task<IActionResult> Delete(int id,CancellationToken ct)
    {
        await batches.DeleteAsync(Actor,id,EntityVersions.Require(Request),ct);return NoContent();
    }
    [HttpGet("{id:int:min(1)}/trace")]
    public async Task<IActionResult> Trace(int id,int? warehouseId=null,int page=1,int pageSize=20,CancellationToken ct=default)
    {
        var result=await batches.TraceAsync(Actor.Id,id,warehouseId,page,pageSize,ct);
        return Ok(new BatchTraceResponse(Map(result.Batch),result.Warehouses.Select(w=>new BatchWarehouseResponse(w.WarehouseId,w.WarehouseName,w.OnHand,w.Reserved,w.Available)).ToArray(),
            new(result.Movements.Items.Select(m=>new BatchMovementResponse(m.Id,m.StockSegmentId,m.BatchId,m.VaccineId,m.WarehouseId,m.QuantityDelta,m.SourceType,m.SourceId,m.SourceDetailId,m.DocumentNo,m.EffectiveDate,m.PostedAt)).ToArray(),
                result.Movements.Page,result.Movements.PageSize,result.Movements.TotalItems,result.Movements.TotalPages)));
    }
    private AdminActor Actor=>new(int.Parse(User.FindFirstValue("sub")!),int.Parse(User.FindFirstValue("authVersion")!));
    private static BatchResponse Map(BatchResult b)=>new(b.Id,b.VaccineId,b.VaccineCode,b.VaccineName,b.BatchNo,b.ManufacturedAt,b.ExpiresAt,b.ExpiryStatus,b.DaysToExpiry,b.Version);
}
