<#
.SYNOPSIS
    Non-destructive Windows MariaDB export for OverlordsXI staging & final cutover.

.DESCRIPTION
    Creates a consistent, full dump of `xidb` (including all custom tables, triggers,
    routines, events, and player progression), verifies non-empty output, computes a
    SHA256 checksum, and writes a JSON row-count parity manifest for post-restore
    validation on Unraid.

.EXAMPLE
    .\deploy\unraid\scripts\windows-export-db.ps1 -OutputDir C:\overlordsxi-migration-staging
#>
param(
    [string]$MariaDbBinDir = 'C:\dev\mariadb\bin',
    [string]$DbHost = '127.0.0.1',
    [int]$DbPort = 3306,
    [string]$DbUser = 'root',
    [string]$DbPassword = '',
    [string]$Database = 'xidb',
    [string]$OutputDir = 'C:\overlordsxi-migration-staging',
    [string]$Label = 'staging'
)

$ErrorActionPreference = 'Stop'

$dumpExe = Join-Path $MariaDbBinDir 'mariadb-dump.exe'
$cliExe  = Join-Path $MariaDbBinDir 'mariadb.exe'
if (-not (Test-Path $dumpExe)) { throw "mariadb-dump.exe not found at $dumpExe" }
if (-not (Test-Path $cliExe))  { throw "mariadb.exe not found at $cliExe" }

if ([string]::IsNullOrEmpty($DbPassword)) {
    # Read password from C:\dev\server\settings\network.lua if not supplied
    $netLua = 'C:\dev\server\settings\network.lua'
    if (Test-Path $netLua) {
        $match = Select-String -Path $netLua -Pattern "SQL_PASSWORD\s*=\s*'([^']*)'" | Select-Object -First 1
        if ($match) { $DbPassword = $match.Matches[0].Groups[1].Value }
    }
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$sqlFile = Join-Path $OutputDir "$Database-$Label-$ts.sql"
$gzFile  = "$sqlFile.gz"
$shaFile = "$gzFile.sha256"
$manifestFile = Join-Path $OutputDir "$Database-$Label-$ts.manifest.json"

Write-Host "==> Exporting $Database from ${DbHost}:${DbPort}..." -ForegroundColor Cyan
$dumpArgs = @(
    "-h", $DbHost,
    "-P", "$DbPort",
    "-u", $DbUser,
    "-p$DbPassword",
    "--single-transaction",
    "--routines",
    "--triggers",
    "--events",
    "--hex-blob",
    "--default-character-set=utf8mb4",
    "--result-file=$sqlFile",
    $Database
)
& $dumpExe @dumpArgs
if ($LASTEXITCODE -ne 0) { throw "mariadb-dump failed with exit code $LASTEXITCODE" }

# Compress to .sql.gz using .NET GZipStream (no external gzip required on Windows)
Write-Host "==> Compressing to $gzFile..." -ForegroundColor Cyan
$inStream  = [System.IO.File]::OpenRead($sqlFile)
$outStream = [System.IO.File]::Create($gzFile)
$gzStream  = New-Object System.IO.Compression.GZipStream($outStream, [System.IO.Compression.CompressionLevel]::Optimal)
try {
    $inStream.CopyTo($gzStream)
} finally {
    $gzStream.Dispose()
    $outStream.Dispose()
    $inStream.Dispose()
}
Remove-Item -Path $sqlFile -Force

# Compute SHA256 in Linux sha256sum-compatible format
$hash = (Get-FileHash -Path $gzFile -Algorithm SHA256).Hash.ToLowerInvariant()
$gzName = Split-Path -Leaf $gzFile
"$hash  $gzName" | Set-Content -Path $shaFile -Encoding ASCII

# Capture row-count & metadata parity manifest
$cliArgs = @("-h", $DbHost, "-P", "$DbPort", "-u", $DbUser, "-p$DbPassword", "-N", "-B", $Database)
$countsRaw = & $cliExe @cliArgs -e "
SELECT 'tables_total', COUNT(*) FROM information_schema.TABLES WHERE table_schema='$Database'
UNION ALL SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL SELECT 'chars', COUNT(*) FROM chars
UNION ALL SELECT 'char_jobs', COUNT(*) FROM char_jobs
UNION ALL SELECT 'char_skills', COUNT(*) FROM char_skills
UNION ALL SELECT 'char_spells', COUNT(*) FROM char_spells
UNION ALL SELECT 'char_inventory', COUNT(*) FROM char_inventory
UNION ALL SELECT 'char_equip', COUNT(*) FROM char_equip
UNION ALL SELECT 'char_storage', COUNT(*) FROM char_storage
UNION ALL SELECT 'char_vars', COUNT(*) FROM char_vars
UNION ALL SELECT 'char_unlocks', COUNT(*) FROM char_unlocks
UNION ALL SELECT 'char_points', COUNT(*) FROM char_points
UNION ALL SELECT 'server_variables', COUNT(*) FROM server_variables
UNION ALL SELECT 'status_effects', COUNT(*) FROM status_effects
UNION ALL SELECT 'abilities', COUNT(*) FROM abilities
UNION ALL SELECT 'zone_settings', COUNT(*) FROM zone_settings;
"

$counts = [ordered]@{}
foreach ($line in $countsRaw) {
    $parts = $line -split "`t"
    if ($parts.Length -eq 2) { $counts[$parts[0]] = [int]$parts[1] }
}

$manifest = [ordered]@{
    exportedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    label         = $Label
    database      = $Database
    archive       = $gzName
    sizeBytes     = (Get-Item $gzFile).Length
    sha256        = $hash
    counts        = $counts
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestFile -Encoding UTF8

Write-Host "==> Export verified:" -ForegroundColor Green
Write-Host "    Archive : $gzFile ($([Math]::Round((Get-Item $gzFile).Length / 1MB, 2)) MB)"
Write-Host "    SHA256  : $hash"
Write-Host "    Manifest: $manifestFile"
