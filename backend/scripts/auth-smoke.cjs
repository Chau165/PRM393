// Run through test-auth.ps1 against its disposable database/server.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const base = process.env.AUTH_SMOKE_URL;
const password = process.env.Seed__Password;
const key = process.env.Jwt__SigningKey;
if (!base || !password || !key) throw Error('Run using test-auth.ps1.');
let checks = 0;
async function request(path, method = 'GET', body, token, expected = 200) {
  const r = await fetch(base + '/api/v1/' + path, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) })
  });
  const data = await r.json();
  assert.equal(r.status, expected, `Unexpected status for ${method} ${path}: ${r.status}, code=${data.code ?? 'none'}`);
  assert.ok(!JSON.stringify(data).includes('passwordHash'), 'Response exposed password hash');
  checks++;
  return data;
}
const login = (username, pass = password, expected = 200) => request('auth/login', 'POST', { username, password: pass }, undefined, expected);
function signed(payload, secret = key) {
  const h = Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
  const p = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256',secret).update(h+'.'+p).digest('base64url');
  return h+'.'+p+'.'+signature;
}
(async () => {
  await request('auth/me','GET',undefined,undefined,401);
  const wrong = await login('staff.hcm','wrong',401);
  const missing = await login('missing.user','wrong',401);
  assert.equal(wrong.code,missing.code);
  assert.equal(wrong.title,missing.title);
  await request('auth/login','POST',{username:'staff.hcm',password,role:'Admin'},undefined,400);
  const a = await login('staff.hcm');
  const b = await login('staff.hcm');
  assert.equal(a.user.role,'WarehouseStaff');
  assert.equal(a.user.warehouses.length,1);
  const quality = await login('quality.hn');
  assert.equal(quality.user.role,'QualityManager');
  assert.notEqual(a.user.warehouses[0].id,quality.user.warehouses[0].id);
  const admin = await login('admin');
  assert.equal(admin.user.warehouses.length,2);
  await request('warehouses/'+a.user.warehouses[0].id,'GET',undefined,a.accessToken);
  await request('warehouses/'+quality.user.warehouses[0].id,'GET',undefined,a.accessToken,404);
  const payload = JSON.parse(Buffer.from(a.accessToken.split('.')[1],'base64url'));
  const now = Math.floor(Date.now()/1000);
  await request('auth/me','GET',undefined,signed({...payload,nbf:now-100,exp:now-1}),401);
  await request('auth/me','GET',undefined,signed({...payload,role:'Admin'}),401);
  await request('auth/me','GET',undefined,signed({...payload,aud:'wrong-audience'}),401);
  await request('auth/me','GET',undefined,signed(payload,'wrong-signing-key-at-least-32-bytes!'),401);
  await request('auth/change-password','POST',{currentPassword:'wrong',newPassword:'New-test-password-123!'},a.accessToken,400);
  await request('auth/change-password','POST',{currentPassword:password,newPassword:'short'},a.accessToken,400);
  await request('auth/change-password','POST',{currentPassword:password,newPassword:'New-test-password-123!'},a.accessToken);
  await request('auth/me','GET',undefined,a.accessToken,401);
  await request('auth/me','GET',undefined,b.accessToken,401);
  await login('staff.hcm',password,401);
  const next = await login('staff.hcm','New-test-password-123!');
  await request('auth/me','GET',undefined,next.accessToken);
  await request('auth/logout','POST',{},next.accessToken);
  await request('auth/me','GET',undefined,next.accessToken,401);
  // Login is limited to ten requests/minute from this source address.
  let limited;
  for (let i=0;i<3;i++) {
    limited = await fetch(base+'/api/v1/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'missing',password:'wrong'})});
    if (limited.status === 429) break;
  }
  assert.equal(limited.status,429);
  assert.ok(limited.headers.get('retry-after'));
  checks++;
  console.log(`PASS: ${checks} HTTP auth checks (JWT, SQL sessions, password change, warehouse scope, rate limit).`);
})().catch(error => { console.error(error.message); process.exitCode = 1; });
