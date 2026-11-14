<#
.SYNOPSIS
    Sets up or updates a local LandSandBoat test server with OverlordsXI customizations on Windows.

.EXAMPLE
    .\scripts\setup-local-server.ps1 -ServerDir C:\dev\server -AshitaAddonsDir C:\Ashita\addons
#>
param(
    [string]$ServerDir = 'C:\dev\server',
    [string]$AshitaAddonsDir = '',
    [string]$DatOverlayDir = 'C:\DATs\Overlords',
    [int]$BuildJobs = 4,
    [switch]$SkipClone,
    [switch]$SkipBuild,
    [switch]$RunDbTool
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Write-Host "==> OverlordsXI root: $RepoRoot" -ForegroundColor Cyan
Write-Host "==> Target LandSandBoat dir: $ServerDir" -ForegroundColor Cyan

function Find-VsDevCmd {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($installPath) {
            $candidate = Join-Path $installPath 'Common7\Tools\VsDevCmd.bat'
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }

    $candidates = @(
        'C:\BuildTools\Common7\Tools\VsDevCmd.bat',
        'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat',
        'C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat',
        'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat'
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) {
            return $p
        }
    }
    return $null
}

# 1. Clone LandSandBoat if needed
if (-not (Test-Path $ServerDir)) {
    if ($SkipClone) {
        throw "ServerDir '$ServerDir' does not exist and -SkipClone was specified."
    }
    Write-Host '==> Cloning landsandboat/server...' -ForegroundColor Yellow
    $parent = Split-Path -Parent $ServerDir
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    git clone --recursive https://github.com/landsandboat/server.git $ServerDir
    if ($LASTEXITCODE -ne 0) {
        throw 'git clone failed.'
    }
}

Push-Location $ServerDir
try {
    # 2. Apply OverlordsXI engine patches idempotently
    $patchFiles = Get-ChildItem -Path (Join-Path $RepoRoot 'patches') -Filter '*.patch' | Sort-Object Name
    function Get-PatchTargetFiles([string]$PatchPath) {
        $files = @()
        foreach ($line in (Get-Content -Path $PatchPath)) {
            if ($line -match '^\+\+\+ b/(.+)$') {
                $files += $matches[1].Trim()
            }
        }
        return $files
    }

    for ($i = 0; $i -lt $patchFiles.Count; $i++) {
        $patch = $patchFiles[$i]
        Write-Host "==> Checking patch: $($patch.Name)" -ForegroundColor Cyan

        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git apply --reverse --check $patch.FullName 2>&1 | Out-Null
        $isReversed = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prevEap

        if ($isReversed) {
            Write-Host "    Already applied, skipping." -ForegroundColor DarkGray
            continue
        }

        $ErrorActionPreference = 'Continue'
        git apply --check $patch.FullName 2>&1 | Out-Null
        $checkCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEap

        if ($checkCode -ne 0) {
            # If a later patch modifying the same file is already applied (e.g. 0005 superseding 0004), skip cleanly
            $curTargets = Get-PatchTargetFiles $patch.FullName
            $supersededBy = $null
            for ($j = $i + 1; $j -lt $patchFiles.Count; $j++) {
                $later = $patchFiles[$j]
                $laterTargets = Get-PatchTargetFiles $later.FullName
                $overlaps = (@($curTargets | Where-Object { $laterTargets -contains $_ })).Count -gt 0
                if ($overlaps) {
                    $prevEap2 = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    git apply --reverse --check $later.FullName 2>&1 | Out-Null
                    $laterApplied = ($LASTEXITCODE -eq 0)
                    $ErrorActionPreference = $prevEap2
                    if ($laterApplied) {
                        $supersededBy = $later.Name
                        break
                    }
                }
            }

            if ($supersededBy) {
                Write-Host "    Already applied (superseded by $supersededBy), skipping." -ForegroundColor DarkGray
                continue
            }

            git apply --check $patch.FullName
            throw "Patch $($patch.Name) failed --check against $ServerDir."
        }

        $ErrorActionPreference = 'Continue'
        git apply $patch.FullName
        $applyCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        if ($applyCode -ne 0) {
            throw "Failed to apply patch $($patch.Name)."
        }
        Write-Host "    Applied." -ForegroundColor Green
    }

    # 3. Copy custom modules (lua, cpp, sql, commands)
    Write-Host '==> Copying OverlordsXI modules...' -ForegroundColor Cyan
    $srcModules = Join-Path $RepoRoot 'modules\custom'
    $dstModules = Join-Path $ServerDir 'modules\custom'
    foreach ($sub in @('lua', 'cpp', 'sql', 'commands')) {
        $srcSub = Join-Path $srcModules $sub
        $dstSub = Join-Path $dstModules $sub
        if ((Test-Path $srcSub) -and ((Get-ChildItem -Path $srcSub -Force | Measure-Object).Count -gt 0)) {
            New-Item -ItemType Directory -Path $dstSub -Force | Out-Null
            Copy-Item -Path (Join-Path $srcSub '*') -Destination $dstSub -Recurse -Force
        }
    }
    $staleWsSql = Join-Path $dstModules 'sql\ws_strip_skillchains.sql'
    if (Test-Path $staleWsSql) {
        Remove-Item -Path $staleWsSql -Force
    }

    # 4. Update modules/init.txt idempotently
    $initPath = Join-Path $ServerDir 'modules\init.txt'
    $initExamplePath = Join-Path $ServerDir 'modules\init.txt.example'
    if (-not (Test-Path $initPath)) {
        if (Test-Path $initExamplePath) {
            Copy-Item -Path $initExamplePath -Destination $initPath
        } else {
            New-Item -ItemType File -Path $initPath -Force | Out-Null
        }
    }

    $initBytes = [System.IO.File]::ReadAllBytes($initPath)
    $hasBom = ($initBytes.Length -ge 3 -and $initBytes[0] -eq 0xEF -and $initBytes[1] -eq 0xBB -and $initBytes[2] -eq 0xBF)

    $existingLines = [System.Collections.Generic.List[string]]::new()
    $removedStale = $false
    foreach ($l in (Get-Content -Path $initPath -ErrorAction SilentlyContinue)) {
        $clean = $l.TrimStart([char]0xFEFF)
        if ($clean.Trim() -eq 'custom/sql/ws_strip_skillchains.sql') {
            $removedStale = $true
            continue
        }
        $existingLines.Add($clean)
    }
    $trimmedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($l in $existingLines) {
        [void]$trimmedSet.Add($l.Trim())
    }

    $appendLines = @(Get-Content -Path (Join-Path $RepoRoot 'modules\init.append.txt') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $addedCount = 0
    foreach ($line in $appendLines) {
        if (-not $trimmedSet.Contains($line)) {
            $existingLines.Add($line)
            [void]$trimmedSet.Add($line)
            $addedCount++
        }
    }
    if ($addedCount -gt 0 -or $removedStale -or $hasBom) {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllLines($initPath, $existingLines, $utf8NoBom)
    }
    Write-Host "==> modules/init.txt updated ($addedCount new entries added)." -ForegroundColor Green

    # 5. Copy DAT overlay
    $srcDat = Join-Path $RepoRoot 'dat-overlay\ROM'
    if ((Test-Path $srcDat) -and ((Get-ChildItem -Path $srcDat -Force | Measure-Object).Count -gt 0)) {
        $dstDat = Join-Path $DatOverlayDir 'ROM'
        New-Item -ItemType Directory -Path $dstDat -Force | Out-Null
        Copy-Item -Path (Join-Path $srcDat '*') -Destination $dstDat -Recurse -Force
        Write-Host "==> Copied DAT overlay to $dstDat" -ForegroundColor Green
    }

    # 6. Copy Ashita v4 addon if target specified
    if ($AshitaAddonsDir -ne '') {
        $srcAddon = Join-Path $RepoRoot 'addons\ashita4\overlords_talents'
        $dstAddon = Join-Path $AshitaAddonsDir 'overlords_talents'
        New-Item -ItemType Directory -Path $dstAddon -Force | Out-Null
        Copy-Item -Path (Join-Path $srcAddon '*') -Destination $dstAddon -Recurse -Force
        Write-Host "==> Installed Ashita v4 addon to $dstAddon" -ForegroundColor Green
    }

    # 7. Configure & build server binaries
    if (-not $SkipBuild) {
        $vsDevCmd = Find-VsDevCmd
        if (-not $vsDevCmd) {
            throw 'Could not find VsDevCmd.bat. Install Visual Studio 2022 / BuildTools or run with -SkipBuild.'
        }

        if (-not (Test-Path (Join-Path $ServerDir 'build\CMakeCache.txt'))) {
            Write-Host '==> Configuring CMake build...' -ForegroundColor Yellow
            cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 && cmake -S . -B build -G Ninja"
            if ($LASTEXITCODE -ne 0) {
                Write-Host '    Ninja generator unavailable, falling back to default CMake generator...' -ForegroundColor DarkGray
                cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 && cmake -S . -B build"
                if ($LASTEXITCODE -ne 0) {
                    throw 'CMake configure failed.'
                }
            }
        }

        Write-Host "==> Building xi_connect, xi_world, xi_search, xi_map (-j $BuildJobs)..." -ForegroundColor Yellow
        cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 && cmake --build build --target xi_connect xi_world xi_search xi_map -j $BuildJobs"
        if ($LASTEXITCODE -ne 0) {
            throw 'CMake build failed.'
        }
        Write-Host '==> Build succeeded.' -ForegroundColor Green
    }

    # 8. Optional dbtool migration
    if ($RunDbTool) {
        Write-Host '==> Running tools/dbtool.py...' -ForegroundColor Yellow
        python tools\dbtool.py
        if ($LASTEXITCODE -ne 0) {
            throw 'dbtool.py failed.'
        }
    }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host '=== Next Steps to Test Locally ===' -ForegroundColor Cyan
Write-Host "1. Configure settings in $ServerDir\settings\ (copy from settings\default\ if first run) and ensure MariaDB is running."
Write-Host "2. Run 'python tools\dbtool.py' inside $ServerDir (if you haven't already) to create/migrate xidb and apply custom SQL modules."
Write-Host "3. Start the server executables from $ServerDir`: xi_connect.exe, xi_world.exe, xi_search.exe, xi_map.exe"
if ($AshitaAddonsDir -eq '') {
    Write-Host "4. Copy addons\ashita4\overlords_talents into your Ashita addons\ folder."
}
Write-Host '5. In-game: /addon load overlords_talents -> /talents (or !talent without the addon).'
