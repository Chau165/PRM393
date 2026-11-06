const assert=require('node:assert/strict');
const base=process.env.AUTH_SMOKE_URL+'/api/v1/',password=process.env.Seed__Password;
let checks=0;
async function call(path,method='GET',body,token,expected=200,etag){
 const r=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(etag?{'If-Match':etag}:{})},...(body===undefined?{}:{body:JSON.stringify(body)})});
 const text=await r.text();const data=text?JSON.parse(text):null;
 assert.equal(r.status,expected,`${method} ${path}: ${r.status}, ${data?.code}`);checks++;
 return {data,etag:r.headers.get('etag'),location:r.headers.get('location')};
}
// Dates match the BE's single Vietnam business calendar, not host local time.
const today=new Date(new Date().toLocaleString('en-US',{timeZone:'Asia/Ho_Chi_Minh'}));
const date=(days)=>{const d=new Date(today);d.setDate(d.getDate()+days);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;};
(async()=>{
 await call('batches','GET',undefined,undefined,401);
 const admin=(await call('auth/login','POST',{username:'admin',password})).data;
 const staff=(await call('auth/login','POST',{username:'staff.hcm',password})).data;
 const quality=(await call('auth/login','POST',{username:'quality.hn',password})).data;
 const a=admin.accessToken,s=staff.accessToken,q=quality.accessToken,hcm=staff.user.warehouseIds[0],hn=quality.user.warehouseIds[0];
 const vaccine=(await call('vaccines?search=TRACE-VAC','GET',undefined,a)).data.items[0];
 const used=(await call('batches?search=TRACE-LOT','GET',undefined,a)).data.items[0];
 await call('batches?pageSize=101','GET',undefined,s,400);
 await call('batches?expiryStatus=Unknown','GET',undefined,s,400);
 await call('batches?sort=unknown','GET',undefined,s,400);
 await call('batches?vaccineId=0','GET',undefined,s,400);
 await call('batches?expiresBefore=bad','GET',undefined,s,400);
 const body={vaccineId:vaccine.id,batchNo:'  NEW-LOT  ',manufacturedAt:null,expiresAt:date(60)};
 const created=await call('batches','POST',body,s,201);const id=created.data.id;
 assert.equal(created.data.batchNo,'NEW-LOT');assert.equal(created.data.expiryStatus,'Valid');assert.equal(created.data.daysToExpiry,60);
 assert.ok(created.location.endsWith('/batches/'+id));assert.equal(created.etag,`"${created.data.version}"`);
 const duplicate=await call('batches','POST',{...body,batchNo:'NEW-LOT'},q,409);assert.equal(duplicate.data.existingBatchId,id);assert.equal(duplicate.data.code,'DUPLICATE_CODE');
 const conflict=await call('batches','POST',{...body,expiresAt:date(61)},a,409);assert.equal(conflict.data.code,'BATCH_METADATA_CONFLICT');assert.equal(conflict.data.existingBatchId,id);
 const changedManufacturing=await call('batches','POST',{...body,manufacturedAt:date(-1)},a,409);assert.equal(changedManufacturing.data.code,'BATCH_METADATA_CONFLICT');
 await call('batches','POST',{...body,batchNo:'  '},s,400);
 await call('batches','POST',{...body,vaccineId:2147483647},s,400);
 await call('batches','POST',{...body,manufacturedAt:date(61)},s,400);
 await call('batches','POST',{vaccineId:vaccine.id,batchNo:'MISSING-EXPIRY'},s,400);
 await call('batches/'+id,'PUT',{manufacturedAt:null,expiresAt:date(30)},s,403,created.etag);
 await call('batches/'+id,'PUT',{manufacturedAt:null,expiresAt:date(30)},a,428);
 await call('batches/'+id,'PUT',{expiresAt:date(30)},a,400,created.etag);
 const updated=await call('batches/'+id,'PUT',{manufacturedAt:null,expiresAt:date(30)},a,200,created.etag);
 assert.equal(updated.data.expiryStatus,'NearExpiry');assert.notEqual(updated.etag,created.etag);
 await call('batches/'+id,'DELETE',undefined,a,412,created.etag);
 await call('batches/'+id,'DELETE',undefined,q,403,updated.etag);
 const unusedTrace=await call('batches/'+id+'/trace','GET',undefined,s);assert.equal(unusedTrace.data.warehouses.length,0);assert.equal(unusedTrace.data.movements.totalItems,0);
 await call('batches/'+id,'DELETE',undefined,a,204,updated.etag);
 await call('batches/'+id,'GET',undefined,s,404);
 const usedGet=await call('batches/'+used.id,'GET',undefined,a);
 await call('batches/'+used.id,'PUT',{manufacturedAt:null,expiresAt:date(100)},a,409,usedGet.etag);
 await call('batches/'+used.id,'DELETE',undefined,a,409,usedGet.etag);
 for(const [days,status] of [[-1,'Expired'],[0,'Expired'],[1,'NearExpiry'],[30,'NearExpiry'],[31,'Valid']]){
  const b=await call('batches','POST',{vaccineId:vaccine.id,batchNo:'BOUNDARY-'+days,expiresAt:date(days)},s,201);
  assert.equal(b.data.expiryStatus,status);assert.equal(b.data.daysToExpiry,days);
  const filtered=await call('batches?search=BOUNDARY-&expiryStatus='+status+'&vaccineId='+vaccine.id+'&sort=batchNo','GET',undefined,q);
  assert.ok(filtered.data.items.some(x=>x.id===b.data.id));
 }
 const before=await call('batches?search=BOUNDARY-&expiresBefore='+date(0),'GET',undefined,s);
 assert.deepEqual(before.data.items.map(x=>x.daysToExpiry),[-1]);
 const trace=await call('batches/'+used.id+'/trace','GET',undefined,s);
 assert.equal(trace.data.warehouses.length,1);assert.equal(trace.data.warehouses[0].warehouseId,hcm);
 assert.equal(trace.data.warehouses[0].onHand,160);assert.equal(trace.data.warehouses[0].reserved,20);assert.equal(trace.data.warehouses[0].available,55);
 assert.equal(trace.data.movements.totalItems,5);assert.ok(!JSON.stringify(trace.data).includes('HN-SECRET'));
 assert.deepEqual([...new Set(trace.data.movements.items.map(x=>x.sourceType))].sort(),['Issue','Receipt','StockDisposition']);
 assert.ok(trace.data.movements.items.every(x=>x.sourceId>0&&x.sourceDetailId>0&&x.warehouseId===hcm));
 const paged=await call('batches/'+used.id+'/trace?pageSize=1&page=2','GET',undefined,s);
 assert.equal(paged.data.movements.items.length,1);assert.equal(paged.data.movements.totalItems,5);assert.equal(paged.data.movements.totalPages,5);
 assert.notEqual(paged.data.movements.items[0].id,trace.data.movements.items[0].id);
 await call('batches/'+used.id+'/trace?warehouseId='+hn,'GET',undefined,s,403);
 await call('batches/'+used.id+'/trace?warehouseId=0','GET',undefined,s,400);
 const qTrace=await call('batches/'+used.id+'/trace','GET',undefined,q);
 assert.equal(qTrace.data.warehouses[0].onHand,200);assert.equal(qTrace.data.warehouses[0].available,175);assert.equal(qTrace.data.movements.totalItems,1);
 const all=await call('batches/'+used.id+'/trace','GET',undefined,a);
 assert.equal(all.data.warehouses.length,2);assert.equal(all.data.movements.totalItems,6);
 const explicit=await call('batches/'+used.id+'/trace?warehouseId='+hn,'GET',undefined,a);assert.equal(explicit.data.warehouses.length,1);
 const expired=(await call('batches?search=EXPIRED-TRACE','GET',undefined,s)).data.items[0];
 const expiredTrace=await call('batches/'+expired.id+'/trace','GET',undefined,s);
 assert.equal(expiredTrace.data.warehouses[0].onHand,100);assert.equal(expiredTrace.data.warehouses[0].available,0);
 for(const batchNo of ['BROKEN-TRACE','NEGATIVE-TRACE']){
  const b=(await call('batches?search='+batchNo,'GET',undefined,s)).data.items[0];
  const invalid=await call('batches/'+b.id+'/trace','GET',undefined,s,409);
  assert.equal(invalid.data.code,'INVENTORY_INTEGRITY_ERROR');assert.ok(!JSON.stringify(invalid.data).includes('HN-SECRET'));
 }
 const anotherVaccine=(await call('vaccines','POST',{code:'SECOND-VAC',name:'Second vaccine',manufacturerId:vaccine.manufacturerId,dosesPerVial:1,vialsPerPack:10,storageMin:2,storageMax:8},a,201)).data;
 await call('batches','POST',{...body,vaccineId:anotherVaccine.id,batchNo:'TRACE-LOT'},q,201);
 const pair=await Promise.all([s,q].map(t=>fetch(base+'batches',{method:'POST',headers:{Authorization:'Bearer '+t,'Content-Type':'application/json'},body:JSON.stringify({...body,batchNo:'CONCURRENT-LOT'})})));
 assert.deepEqual(pair.map(r=>r.status).sort(),[201,409]);checks+=2;
 console.log(`PASS: ${checks} HTTP batch checks (CRUD, duplicate metadata, expiry boundaries, ETags, reference locks, scoped trace and stock arithmetic).`);
})().catch(e=>{console.error(e.message);process.exitCode=1;});
