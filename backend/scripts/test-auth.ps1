param([ValidateSet('auth','admin','catalog','batch','warehouse-fe','catalog-fe','batch-fe')][string]$Suite = 'auth', [string]$BuildConfiguration = 'Debug')
$ErrorActionPreference = 'Stop'
$backendRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testDatabase = 'VaxStockAuthTest_' + [Guid]::NewGuid().ToString('N')
if ($testDatabase -notmatch '^VaxStockAuthTest_[a-f0-9]{32}$') { throw 'Invalid test database name.' }
$results = Join-Path $backendRoot 'test-results'
New-Item -ItemType Directory -Force -Path $results | Out-Null
$names = @('ConnectionStrings__Warehouse','Jwt__SigningKey','Jwt__Issuer','Jwt__Audience','Seed__Password','ASPNETCORE_ENVIRONMENT','AUTH_SMOKE_URL','Logging__LogLevel__Default','Logging__LogLevel__Microsoft','WAREHOUSE_LIVE_API_URL','Cors__Origins__0')
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
$server = $null
Push-Location $backendRoot
try {
    $env:ConnectionStrings__Warehouse = "Server=localhost;Database=$testDatabase;Integrated Security=True;Encrypt=True;TrustServerCertificate=True"
    $env:Jwt__SigningKey = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
    $env:Jwt__Issuer = 'VaxStock.Api'
    $env:Jwt__Audience = 'VaxStock.Flutter'
    $env:Seed__Password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:Logging__LogLevel__Default = 'Warning'
    $env:Logging__LogLevel__Microsoft = 'Warning'
    $env:Cors__Origins__0 = 'http://localhost:5173'
    # Reserve an unused local port; release immediately before starting our server.
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    $env:AUTH_SMOKE_URL = "http://127.0.0.1:$port"
    dotnet ef database update --project VaxStock.DataAccess --startup-project VaxStock.Api --configuration $BuildConfiguration --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Test database migration failed.' }
    dotnet run --project VaxStock.Api --configuration $BuildConfiguration --no-build --no-launch-profile -- --seed-auth true
    if ($LASTEXITCODE -ne 0) { throw 'Test seed failed.' }
    if ($Suite -eq 'catalog') {
        sqlcmd -S localhost -E -C -d $testDatabase -b -i (Join-Path $PSScriptRoot 'catalog-fixture.sql') -W
        if ($LASTEXITCODE -ne 0) { throw 'Catalog fixture failed.' }
    }
    if ($Suite -in @('batch','batch-fe')) {
        sqlcmd -S localhost -E -C -d $testDatabase -b -i (Join-Path $PSScriptRoot 'batch-fixture.sql') -W
        if ($LASTEXITCODE -ne 0) { throw 'Batch fixture failed.' }
    }
    $dll = Join-Path $backendRoot "VaxStock.Api/bin/$BuildConfiguration/net10.0/VaxStock.Api.dll"
    $server = Start-Process dotnet -ArgumentList @(('"' + $dll + '"'),'--urls',$env:AUTH_SMOKE_URL) -WorkingDirectory (Join-Path $backendRoot 'VaxStock.Api') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $results 'auth-server.out.log') -RedirectStandardError (Join-Path $results 'auth-server.err.log')
    $ready = $false
    for ($attempt=0; $attempt -lt 30; $attempt++) {
        try { Invoke-RestMethod ($env:AUTH_SMOKE_URL + '/health') -TimeoutSec 1 | Out-Null; $ready=$true; break } catch { Start-Sleep -Milliseconds 300 }
    }
    if (!$ready) { throw 'Test API did not start. See backend/test-results/auth-server.err.log.' }
    if ($Suite -in @('warehouse-fe','catalog-fe','batch-fe')) {
        $env:WAREHOUSE_LIVE_API_URL = $env:AUTH_SMOKE_URL + '/api/v1/'
        Push-Location ([IO.Path]::GetFullPath((Join-Path $backendRoot '..')))
        try {
            $flutterTest = switch ($Suite) { 'catalog-fe' { 'test/catalog_api_live_test.dart' }; 'batch-fe' { 'test/batch_api_live_test.dart' }; default { 'test/warehouse_api_live_test.dart' } }
            flutter --no-version-check test --no-pub $flutterTest
            if ($LASTEXITCODE -ne 0) { throw 'Flutter live API test failed.' }
        } finally { Pop-Location }
    } else {
        $smokeScript = switch ($Suite) { 'admin' { 'user-management-smoke.cjs' }; 'catalog' { 'catalog-smoke.cjs' }; 'batch' { 'batch-smoke.cjs' }; default { 'auth-smoke.cjs' } }
        node (Join-Path $PSScriptRoot $smokeScript)
        if ($LASTEXITCODE -ne 0) { throw 'HTTP smoke tests failed.' }
    }
    if ($Suite -eq 'admin') {
        sqlcmd -S localhost -E -C -d $testDatabase -b -i (Join-Path $PSScriptRoot 'verify-user-management.sql') -W
        if ($LASTEXITCODE -ne 0) { throw 'User management audit verification failed.' }
    }
    if ($Suite -eq 'catalog') {
        sqlcmd -S localhost -E -C -d $testDatabase -b -i (Join-Path $PSScriptRoot 'verify-catalog.sql') -W
        if ($LASTEXITCODE -ne 0) { throw 'Catalog audit verification failed.' }
    }
    if ($Suite -eq 'batch') {
        sqlcmd -S localhost -E -C -d $testDatabase -b -i (Join-Path $PSScriptRoot 'verify-batch.sql') -W
        if ($LASTEXITCODE -ne 0) { throw 'Batch audit verification failed.' }
    }
}
finally {
    if ($server -and !$server.HasExited) { Stop-Process -Id $server.Id -Force }
    # Only remove the uniquely named database created by this run. Never VaxStockDev.
    if ($testDatabase -match '^VaxStockAuthTest_[a-f0-9]{32}$') {
        sqlcmd -S localhost -E -C -d master -b -Q "IF DB_ID(N'$testDatabase') IS NOT NULL BEGIN ALTER DATABASE [$testDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$testDatabase]; END" | Out-Null
    }
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$saved[$name],'Process') }
    Pop-Location
}
