const assert = require('node:assert/strict');
const base = process.env.AUTH_SMOKE_URL;
const password = process.env.Seed__Password;
if (!base || !password) throw Error('Run test-auth.ps1 -Suite admin.');
let checks = 0;
async function call(path, method='GET', body, token, expected=200, etag) {
  const response = await fetch(base+'/api/v1/'+path, {method,
    headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(etag?{'If-Match':etag}:{})},
    ...(body === undefined ? {} : {body:JSON.stringify(body)})});
  const text=await response.text(); const data=text?JSON.parse(text):null;
  assert.equal(response.status,expected,`${method} ${path}: status=${response.status}, code=${data?.code}`);
  assert.ok(!text.includes('passwordHash') && !text.includes('authVersion'), 'Private credential field exposed');
  checks++;
  return {data,etag:response.headers.get('etag'),location:response.headers.get('location')};
}
async function login(username, pass=password, expected=200) {
  return (await call('auth/login','POST',{username,password:pass},undefined,expected)).data;
}
(async()=>{
  await call('users','GET',undefined,undefined,401);
  const admin=await login('admin'), staff=await login('staff.hcm'), quality=await login('quality.hn');
  const a=admin.accessToken; const whA=staff.user.warehouseIds[0], whB=quality.user.warehouseIds[0];
  assert.ok(admin.user.version); assert.equal(admin.user.warehouseIds.length,2);
  await call('users','GET',undefined,staff.accessToken,403);
  await call('warehouse-assignments','GET',undefined,quality.accessToken,403);
  const me=await call('auth/me','GET',undefined,a); assert.equal(me.etag,`"${me.data.version}"`);
  await call('users?page=0','GET',undefined,a,400);
  await call('users?pageSize=101','GET',undefined,a,400);
  await call('users?role=Owner','GET',undefined,a,400);
  await call('users?sort=password','GET',undefined,a,400);
  const filtered=await call('users?role=WarehouseStaff&sort=id&pageSize=1','GET',undefined,a);
  assert.equal(filtered.data.items.length,1); assert.equal(filtered.data.totalItems,1);
  await call('users/2147483647','GET',undefined,a,404);
  const body={username:'  Management.New  ',password,fullName:'New account',role:'WarehouseStaff'};
  const created=await call('users','POST',body,a,201);
  const id=created.data.id;
  assert.equal(created.data.username,'management.new'); assert.deepEqual(created.data.warehouseIds,[]);
  assert.ok(created.location.endsWith('/users/'+id)); assert.equal(created.etag,`"${created.data.version}"`);
  await call('users','POST',{...body,username:'MANAGEMENT.NEW'},a,409);
  await call('users','POST',{...body,username:'other',password:'short'},a,400);
  await call('users','POST',{...body,username:'other',fullName:'   '},a,400);
  await call('users','POST',{...body,username:'other',role:'Owner'},a,400);
  const update={fullName:'Updated account',role:'WarehouseStaff'};
  await call('users/'+id,'PUT',update,a,428);
  await call('users/'+id,'PUT',update,a,400,'*');
  await call('users/'+id,'PUT',update,a,400,'W/'+created.etag);
  await call('users/'+id,'PUT',update,a,412,'"AAAAAAAAAAA="');
  const updated=await call('users/'+id,'PUT',update,a,200,created.etag);
  assert.notEqual(updated.etag,created.etag);
  await call('users/'+id,'PUT',update,a,412,created.etag);
  await call('users/'+id,'PUT',{...update,username:'renamed'},a,400,updated.etag);
  const newcomer=await login('management.new'); const t=newcomer.accessToken;
  await call('warehouses/'+whA,'GET',undefined,t,404);
  await call('warehouse-assignments','POST',{userId:id,warehouseId:whA},staff.accessToken,403);
  await call('warehouse-assignments','POST',{userId:id,warehouseId:2147483647},a,400);
  const granted=await call('warehouse-assignments','POST',{userId:id,warehouseId:whA},a,201);
  assert.ok(granted.location.endsWith('/warehouse-assignments/'+granted.data.id));
  const grantRead=await call('warehouse-assignments/'+granted.data.id,'GET',undefined,a);
  assert.equal(grantRead.etag,granted.etag);
  await call('warehouse-assignments','POST',{userId:id,warehouseId:whA},a,409);
  await call('warehouses/'+whA,'GET',undefined,t);
  const assigned=await call('auth/me','GET',undefined,t);
  assert.deepEqual(assigned.data.warehouseIds,[whA]);
  await call('users/'+id,'PUT',update,a,412,updated.etag); // grant changes aggregate version
  const assignmentPage=await call('warehouse-assignments?userId='+id+'&warehouseId='+whA,'GET',undefined,a);
  assert.equal(assignmentPage.data.totalItems,1);
  await call('warehouse-assignments?userId=0','GET',undefined,a,400);
  await call('warehouse-assignments/'+granted.data.id,'DELETE',undefined,a,428);
  await call('warehouse-assignments/'+granted.data.id,'DELETE',undefined,a,412,'"AAAAAAAAAAA="');
  await call('warehouse-assignments/'+granted.data.id,'DELETE',undefined,a,204,granted.etag);
  await call('warehouse-assignments/'+granted.data.id,'GET',undefined,a,404);
  await call('warehouses/'+whA,'GET',undefined,t,404); // same JWT, permission revoked immediately
  const noGrant=await call('auth/me','GET',undefined,t); assert.deepEqual(noGrant.data.warehouseIds,[]);
  // Duplicate concurrent grants are serialized; exactly one succeeds.
  const pair=await Promise.all([1,2].map(()=>fetch(base+'/api/v1/warehouse-assignments',{method:'POST',headers:{Authorization:'Bearer '+a,'Content-Type':'application/json'},body:JSON.stringify({userId:id,warehouseId:whB})})));
  assert.deepEqual(pair.map(r=>r.status).sort(),[201,409]); checks+=2;
  let current=await call('users/'+id,'GET',undefined,a);
  await call('users/'+id+'/reset-password','POST',{newPassword:'Changed-password-123!',reason:'   '},a,400,current.etag);
  await call('users/'+id+'/reset-password','POST',{newPassword:'Changed-password-123!',reason:'Reset'},staff.accessToken,403,current.etag);
  const longReason='Đ"'.repeat(1000);
  const reset=await call('users/'+id+'/reset-password','POST',{newPassword:'Changed-password-123!',reason:longReason},a,200,current.etag);
  assert.equal(reset.data.reauthenticationRequired,true); assert.notEqual(reset.etag,current.etag);
  await call('auth/me','GET',undefined,t,401);
  await login('management.new',password,401);
  const changed=await login('management.new','Changed-password-123!');
  current=await call('users/'+id,'GET',undefined,a);
  await call('users/'+id,'PUT',{fullName:'Updated account',role:'QualityManager'},a,200,current.etag);
  await call('auth/me','GET',undefined,changed.accessToken,401);
  const last=await call('users/'+admin.user.id,'GET',undefined,a);
  const lastResult=await call('users/'+admin.user.id,'PUT',{fullName:'Admin',role:'WarehouseStaff'},a,409,last.etag);
  assert.equal(lastResult.data.code,'LAST_ADMIN_REQUIRED');
  const second=await call('users','POST',{username:'management.admin2',password,fullName:'Second admin',role:'Admin'},a,201);
  const admin2=await login('management.admin2');
  const primaryState=await call('users/'+admin.user.id,'GET',undefined,a);
  const secondaryState=await call('users/'+second.data.id,'GET',undefined,a);
  const demotions=await Promise.all([
    [admin.user.id,a,primaryState.etag],[second.data.id,admin2.accessToken,secondaryState.etag]
  ].map(([userId,token,etag])=>fetch(base+'/api/v1/users/'+userId,{method:'PUT',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json','If-Match':etag},body:JSON.stringify({fullName:'Demotion attempt',role:'WarehouseStaff'})})));
  assert.deepEqual(demotions.map(r=>r.status).sort(),[200,409]); checks+=2;
  const demoted=demotions[0].status===200?a:admin2.accessToken;
  const surviving=demotions[0].status===409?a:admin2.accessToken;
  await call('auth/me','GET',undefined,demoted,401);
  const admins=await call('users?role=Admin','GET',undefined,surviving); assert.equal(admins.data.totalItems,1);
  console.log(`PASS: ${checks} HTTP user/assignment checks (Admin authorization, ETags, reset, role revocation, warehouse scope, concurrent last-admin protection).`);
})().catch(e=>{console.error(e.message);process.exitCode=1;});
