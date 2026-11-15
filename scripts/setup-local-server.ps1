<#
.SYNOPSIS
    Sets up or updates a local LandSandBoat test server with OverlordsXI customizations on Windows.

.DESCRIPTION
    Applies OverlordsXI patches idempotently, syncs custom modules/DAT/addon files only when contents
    changed (preserving C++ file timestamps), and runs CMake builds only for executables whose C++
    or CMake inputs actually changed since the last build.

.EXAMPLE
    .\scripts\setup-local-server.ps1 -ServerDir C:\dev\server -AshitaAddonsDir C:\Ashita\addons
#>
param(
    [string]$ServerDir = 'C:\dev\server',
    [string]$AshitaAddonsDir = '',
    [string]$DatOverlayDir = 'C:\DATs\Overlords',
    [int]$BuildJobs = 0,
    [switch]$SkipClone,
    [switch]$SkipBuild,
    [switch]$ForceBuild,
    [switch]$MapOnly,
    [switch]$RunDbTool
)

$ErrorActionPreference = 'Stop'

if ($BuildJobs -le 0) {
    $BuildJobs = [Math]::Max(1, [Environment]::ProcessorCount)
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$LogDir = Join-Path $RepoRoot 'logs'
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile = Join-Path $LogDir "setup-$Timestamp.log"
$LatestLogFile = Join-Path $LogDir 'setup-latest.log'
Start-Transcript -Path $LogFile -Force | Out-Null

Write-Host "==> OverlordsXI root: $RepoRoot" -ForegroundColor Cyan
Write-Host "==> Target LandSandBoat dir: $ServerDir" -ForegroundColor Cyan
Write-Host "==> Logging output to: $LogFile" -ForegroundColor Cyan

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

function Sync-DirectoryChangedOnly {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestDir
    )

    $changedFiles = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path $SourceDir)) {
        return $changedFiles
    }

    $srcRoot = (Resolve-Path $SourceDir).Path.TrimEnd('\', '/')
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    $dstRoot = (Resolve-Path $DestDir).Path.TrimEnd('\', '/')

    foreach ($srcFile in (Get-ChildItem -Path $srcRoot -File -Recurse)) {
        $relPath = $srcFile.FullName.Substring($srcRoot.Length).TrimStart('\', '/')
        $dstPath = Join-Path $dstRoot $relPath
        $dstParent = Split-Path -Parent $dstPath
        if ($dstParent -and -not (Test-Path $dstParent)) {
            New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
        }

        $needsCopy = $true
        if (Test-Path $dstPath) {
            $dstInfo = Get-Item -Path $dstPath
            if ($dstInfo.Length -eq $srcFile.Length) {
                $srcHash = (Get-FileHash -Path $srcFile.FullName -Algorithm SHA256).Hash
                $dstHash = (Get-FileHash -Path $dstPath -Algorithm SHA256).Hash
                if ($srcHash -eq $dstHash) {
                    $needsCopy = $false
                }
            }
        }

        if ($needsCopy) {
            Copy-Item -Path $srcFile.FullName -Destination $dstPath -Force
            [void]$changedFiles.Add(($relPath -replace '\\', '/'))
        }
    }

    return $changedFiles
}

function Get-DirectoryFileHashes {
    param([string]$RootDir)

    $hashes = @{}
    if (-not (Test-Path $RootDir)) {
        return $hashes
    }

    $basePath = (Resolve-Path $RootDir).Path.TrimEnd('\', '/')
    foreach ($f in (Get-ChildItem -Path $basePath -File -Recurse)) {
        $rel = ($f.FullName.Substring($basePath.Length).TrimStart('\', '/')) -replace '\\', '/'
        $hashes[$rel] = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
    }
    return $hashes
}

function Add-AffectedTargetsForPath {
    param(
        [string]$RelPath,
        [System.Collections.Generic.HashSet[string]]$TargetSet
    )

    if ([string]::IsNullOrWhiteSpace($RelPath)) {
        return
    }

    $norm = ($RelPath -replace '\\', '/').TrimStart('./')
    if ($norm -match '^src/(profile|test)/') {
        return
    }
    if ($norm -match '^src/map/' -or $norm -match '^modules/custom/cpp/') {
        [void]$TargetSet.Add('xi_map')
        return
    }
    if ($norm -match '^src/login/') {
        [void]$TargetSet.Add('xi_connect')
        return
    }
    if ($norm -match '^src/world/') {
        [void]$TargetSet.Add('xi_world')
        return
    }
    if ($norm -match '^src/search/') {
        [void]$TargetSet.Add('xi_search')
        return
    }
    if (
        $norm -match '^src/' -or
        $norm -match '^ext/' -or
        $norm -match '^cmake/' -or
        $norm -match '^res/' -or
        $norm -eq 'CMakeLists.txt' -or
        $norm -eq 'CMakePresets.json' -or
        $norm -eq 'modules/CMakeLists.txt'
    ) {
        foreach ($t in @('xi_connect', 'xi_world', 'xi_search', 'xi_map')) {
            [void]$TargetSet.Add($t)
        }
    }
}

function Get-NewestWriteTimeUtc {
    param([string[]]$Paths)

    $newest = [datetime]::MinValue
    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) {
            continue
        }
        $item = Get-Item -Path $p
        if (-not $item.PSIsContainer) {
            if ($item.LastWriteTimeUtc -gt $newest) {
                $newest = $item.LastWriteTimeUtc
            }
            continue
        }

        foreach ($fullPath in [System.IO.Directory]::EnumerateFiles($item.FullName, '*', [System.IO.SearchOption]::AllDirectories)) {
            $t = [System.IO.File]::GetLastWriteTimeUtc($fullPath)
            if ($t -gt $newest) {
                $newest = $t
            }
        }
    }
    return $newest
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
    $newlyAppliedPatchTargetFiles = [System.Collections.Generic.List[string]]::new()

    function Get-PatchTargetFiles([string]$PatchPath) {
        $files = @()
        foreach ($line in (Get-Content -Path $PatchPath)) {
            if ($line -match '^\+\+\+ b/(.+)$') {
                $files += $matches[1].Trim()
            }
        }
        return $files
    }

    function Test-PatchApplied([string]$PatchPath) {
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git apply --reverse --check $PatchPath 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $ErrorActionPreference = $prev
            return $true
        }
        git apply --reverse --check --ignore-space-change $PatchPath 2>&1 | Out-Null
        $ok = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $prev
        return $ok
    }

    for ($i = 0; $i -lt $patchFiles.Count; $i++) {
        $patch = $patchFiles[$i]
        Write-Host "==> Checking patch: $($patch.Name)" -ForegroundColor Cyan

        if (Test-PatchApplied $patch.FullName) {
            Write-Host "    Already applied, skipping." -ForegroundColor DarkGray
            continue
        }

        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $useIgnoreSpace = $false
        git apply --check $patch.FullName 2>&1 | Out-Null
        $checkCode = $LASTEXITCODE
        if ($checkCode -ne 0) {
            git apply --check --ignore-space-change $patch.FullName 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $checkCode = 0
                $useIgnoreSpace = $true
            }
        }
        $ErrorActionPreference = $prevEap

        if ($checkCode -ne 0) {
            # If a later patch modifying the same file is already applied (e.g. 0005 superseding 0004), skip cleanly
            $curTargets = Get-PatchTargetFiles $patch.FullName
            $supersededBy = $null
            for ($j = $i + 1; $j -lt $patchFiles.Count; $j++) {
                $later = $patchFiles[$j]
                $laterTargets = Get-PatchTargetFiles $later.FullName
                $overlaps = (@($curTargets | Where-Object { $laterTargets -contains $_ })).Count -gt 0
                if ($overlaps -and (Test-PatchApplied $later.FullName)) {
                    $supersededBy = $later.Name
                    break
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
        if ($useIgnoreSpace) {
            git apply --ignore-space-change $patch.FullName
        } else {
            git apply $patch.FullName
        }
        $applyCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        if ($applyCode -ne 0) {
            throw "Failed to apply patch $($patch.Name)."
        }

        foreach ($tf in (Get-PatchTargetFiles $patch.FullName)) {
            [void]$newlyAppliedPatchTargetFiles.Add($tf)
        }
        Write-Host "    Applied." -ForegroundColor Green
    }

    # 3. Sync custom modules (lua, cpp, sql, commands) without clobbering timestamps on unchanged files
    Write-Host '==> Syncing OverlordsXI modules...' -ForegroundColor Cyan
    $srcModules = Join-Path $RepoRoot 'modules\custom'
    $dstModules = Join-Path $ServerDir 'modules\custom'
    $changedCppFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($sub in @('lua', 'cpp', 'sql', 'commands')) {
        $srcSub = Join-Path $srcModules $sub
        $dstSub = Join-Path $dstModules $sub
        if ((Test-Path $srcSub) -and ((Get-ChildItem -Path $srcSub -Force | Measure-Object).Count -gt 0)) {
            $synced = Sync-DirectoryChangedOnly -SourceDir $srcSub -DestDir $dstSub
            if ($sub -eq 'cpp') {
                foreach ($f in $synced) {
                    [void]$changedCppFiles.Add("modules/custom/cpp/$f")
                }
            }
        }
    }
    $staleSqlFiles = @(
        'sql\ws_strip_skillchains.sql',
        'sql\war_specs.sql',
        'sql\mnk_specs.sql'
    )
    foreach ($relSql in $staleSqlFiles) {
        $stalePath = Join-Path $dstModules $relSql
        if (Test-Path $stalePath) {
            Remove-Item -Path $stalePath -Force
        }
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

    $staleInitLines = @(
        'custom/sql/ws_strip_skillchains.sql',
        'custom/sql/war_specs.sql',
        'custom/sql/mnk_specs.sql'
    )
    $existingLines = [System.Collections.Generic.List[string]]::new()
    $removedStale = $false
    foreach ($l in (Get-Content -Path $initPath -ErrorAction SilentlyContinue)) {
        $clean = $l.TrimStart([char]0xFEFF)
        if ($staleInitLines -contains $clean.Trim()) {
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

    # 5. Sync DAT overlay
    $srcDat = Join-Path $RepoRoot 'dat-overlay\ROM'
    if ((Test-Path $srcDat) -and ((Get-ChildItem -Path $srcDat -Force | Measure-Object).Count -gt 0)) {
        $dstDat = Join-Path $DatOverlayDir 'ROM'
        $changedDat = Sync-DirectoryChangedOnly -SourceDir $srcDat -DestDir $dstDat
        Write-Host "==> Synced DAT overlay to $dstDat ($($changedDat.Count) file(s) updated)" -ForegroundColor Green
    }

    # 6. Sync Ashita v4 addon if present and target specified
    if ($AshitaAddonsDir -ne '') {
        $srcAddon = Join-Path $RepoRoot 'addons\ashita4\overlords_talents'
        if (Test-Path $srcAddon) {
            $dstAddon = Join-Path $AshitaAddonsDir 'overlords_talents'
            $changedAddon = Sync-DirectoryChangedOnly -SourceDir $srcAddon -DestDir $dstAddon
            Write-Host "==> Synced Ashita v4 addon to $dstAddon ($($changedAddon.Count) file(s) updated)" -ForegroundColor Green
        }
    }

    # 7. Configure & build server binaries only when C++/CMake inputs changed
    if (-not $SkipBuild) {
        $allServerTargets = @('xi_connect', 'xi_world', 'xi_search', 'xi_map')
        $scopedTargets = if ($MapOnly) { @('xi_map') } else { $allServerTargets }

        $buildDir = Join-Path $ServerDir 'build'
        $cmakeCachePath = Join-Path $buildDir 'CMakeCache.txt'
        $buildStatePath = Join-Path $buildDir '.overlords_build_state.json'

        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $headOut = git rev-parse HEAD 2>$null
        $headExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        $currentHead = if ($headExit -eq 0 -and $headOut) { ([string]$headOut).Trim() } else { '' }
        $currentCppHashes = Get-DirectoryFileHashes -RootDir (Join-Path $ServerDir 'modules\custom\cpp')
        $needsConfigure = -not (Test-Path $cmakeCachePath)

        $savedState = $null
        if (Test-Path $buildStatePath) {
            try {
                $savedState = Get-Content -Path $buildStatePath -Raw | ConvertFrom-Json
            } catch {
                $savedState = $null
            }
        }

        $targetsToBuild = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $buildReasons = [System.Collections.Generic.List[string]]::new()

        if ($ForceBuild) {
            foreach ($t in $scopedTargets) {
                [void]$targetsToBuild.Add($t)
            }
            [void]$buildReasons.Add('-ForceBuild specified')
        }
        elseif ($needsConfigure) {
            foreach ($t in $scopedTargets) {
                [void]$targetsToBuild.Add($t)
            }
            [void]$buildReasons.Add('CMake cache missing (fresh configure)')
        }
        else {
            # a) Newly applied patches in this run
            foreach ($tf in $newlyAppliedPatchTargetFiles) {
                Add-AffectedTargetsForPath -RelPath $tf -TargetSet $targetsToBuild
            }
            if ($newlyAppliedPatchTargetFiles.Count -gt 0) {
                [void]$buildReasons.Add("$($newlyAppliedPatchTargetFiles.Count) patched source file(s) applied")
            }

            # b) Newly added or updated custom C++ modules
            foreach ($cf in $changedCppFiles) {
                Add-AffectedTargetsForPath -RelPath $cf -TargetSet $targetsToBuild
            }
            if ($changedCppFiles.Count -gt 0) {
                [void]$buildReasons.Add("$($changedCppFiles.Count) custom C++ file(s) synced")
            }

            # c) Custom C++ file additions/removals/edits compared to last build state
            if ($savedState -and $savedState.cppHashes) {
                $prevCppMap = @{}
                foreach ($prop in $savedState.cppHashes.PSObject.Properties) {
                    $prevCppMap[$prop.Name] = [string]$prop.Value
                }
                $cppDrift = $false
                foreach ($k in $currentCppHashes.Keys) {
                    if (-not $prevCppMap.ContainsKey($k) -or $prevCppMap[$k] -ne $currentCppHashes[$k]) {
                        $cppDrift = $true
                        break
                    }
                }
                if (-not $cppDrift) {
                    foreach ($k in $prevCppMap.Keys) {
                        if (-not $currentCppHashes.ContainsKey($k)) {
                            $cppDrift = $true
                            break
                        }
                    }
                }
                if ($cppDrift) {
                    [void]$targetsToBuild.Add('xi_map')
                    [void]$buildReasons.Add('modules/custom/cpp differs from last build state')
                }
            }

            # d) Upstream LandSandBoat git HEAD changes per target since last build
            foreach ($t in $scopedTargets) {
                if ($targetsToBuild.Contains($t)) {
                    continue
                }
                $prevHead = $null
                if ($savedState -and $savedState.targetHeads -and $savedState.targetHeads.PSObject.Properties[$t]) {
                    $prevHead = [string]$savedState.targetHeads.$t
                }
                if ($prevHead -and $currentHead -and $prevHead -ne $currentHead) {
                    $diffSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                    $prevEap = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    $diffFiles = git diff --name-only "$prevHead..$currentHead" 2>$null
                    $diffExit = $LASTEXITCODE
                    $ErrorActionPreference = $prevEap
                    if ($diffExit -ne 0) {
                        [void]$targetsToBuild.Add($t)
                        [void]$buildReasons.Add("git HEAD changed for $t")
                    } else {
                        foreach ($df in $diffFiles) {
                            Add-AffectedTargetsForPath -RelPath $df -TargetSet $diffSet
                        }
                        if ($diffSet.Contains($t)) {
                            [void]$targetsToBuild.Add($t)
                            [void]$buildReasons.Add("upstream C++/CMake commit changed $t")
                        }
                    }
                }
            }

            # e) Missing binaries or any C++/CMake file modified more recently than its last build
            $exeUtcByTarget = @{}
            foreach ($t in $scopedTargets) {
                $exePath = Join-Path $ServerDir "$t.exe"
                if (-not (Test-Path $exePath)) {
                    [void]$targetsToBuild.Add($t)
                    [void]$buildReasons.Add("$t.exe missing")
                } else {
                    $cutoffUtc = (Get-Item -Path $exePath).LastWriteTimeUtc
                    if ($savedState -and $savedState.targetBuildUtc -and $savedState.targetBuildUtc.PSObject.Properties[$t]) {
                        try {
                            $savedUtc = [datetime]::Parse([string]$savedState.targetBuildUtc.$t, $null, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
                            if ($savedUtc -gt $cutoffUtc) {
                                $cutoffUtc = $savedUtc
                            }
                        } catch {
                        }
                    }
                    $exeUtcByTarget[$t] = $cutoffUtc
                }
            }

            $remainingTargets = @($scopedTargets | Where-Object { -not $targetsToBuild.Contains($_) })
            if ($remainingTargets.Count -gt 0) {
                $newestSharedUtc = Get-NewestWriteTimeUtc -Paths @(
                    (Join-Path $ServerDir 'CMakeLists.txt'),
                    (Join-Path $ServerDir 'CMakePresets.json'),
                    (Join-Path $ServerDir 'cmake'),
                    (Join-Path $ServerDir 'ext'),
                    (Join-Path $ServerDir 'res'),
                    (Join-Path $ServerDir 'src\CMakeLists.txt'),
                    (Join-Path $ServerDir 'src\common'),
                    (Join-Path $ServerDir 'modules\CMakeLists.txt')
                )

                foreach ($t in $remainingTargets) {
                    if ($newestSharedUtc -gt $exeUtcByTarget[$t]) {
                        [void]$targetsToBuild.Add($t)
                        [void]$buildReasons.Add("shared C++/CMake files newer than $t")
                    }
                }

                $targetSpecificDirs = @{
                    'xi_connect' = @((Join-Path $ServerDir 'src\login'))
                    'xi_world'   = @((Join-Path $ServerDir 'src\world'))
                    'xi_search'  = @((Join-Path $ServerDir 'src\search'))
                    'xi_map'     = @((Join-Path $ServerDir 'src\map'), (Join-Path $ServerDir 'modules\custom\cpp'))
                }
                foreach ($t in $remainingTargets) {
                    if ($targetsToBuild.Contains($t)) {
                        continue
                    }
                    $newestOwnUtc = Get-NewestWriteTimeUtc -Paths $targetSpecificDirs[$t]
                    if ($newestOwnUtc -gt $exeUtcByTarget[$t]) {
                        [void]$targetsToBuild.Add($t)
                        [void]$buildReasons.Add("target source newer than $t")
                    }
                }
            }
        }

        $finalTargets = @($scopedTargets | Where-Object { $targetsToBuild.Contains($_) })

        if ($finalTargets.Count -eq 0) {
            Write-Host '==> No C++/CMake changes detected; skipping build. (Use -ForceBuild to rebuild anyway.)' -ForegroundColor Green

            # Bootstrap state file if exes are already verified up-to-date
            if (-not (Test-Path $buildStatePath) -and (Test-Path $buildDir)) {
                $nowIso = (Get-Date).ToUniversalTime().ToString('o')
                $targetHeadsMap = @{}
                $targetBuildUtcMap = @{}
                foreach ($t in $scopedTargets) {
                    $targetHeadsMap[$t] = $currentHead
                    $targetBuildUtcMap[$t] = $nowIso
                }
                $stateObj = [ordered]@{
                    lastBuildUtc   = $nowIso
                    targetHeads    = $targetHeadsMap
                    targetBuildUtc = $targetBuildUtcMap
                    cppHashes      = $currentCppHashes
                }
                $stateObj | ConvertTo-Json -Depth 4 | Set-Content -Path $buildStatePath -Encoding UTF8
            }
        }
        else {
            $vsDevCmd = Find-VsDevCmd
            if (-not $vsDevCmd) {
                throw 'Could not find VsDevCmd.bat. Install Visual Studio 2022 / BuildTools or run with -SkipBuild.'
            }

            if ($needsConfigure) {
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

            $reasonSummary = ($buildReasons | Select-Object -Unique) -join '; '
            $targetArgs = $finalTargets -join ' '
            Write-Host "==> Building $targetArgs (-j $BuildJobs) [$reasonSummary]..." -ForegroundColor Yellow
            cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 && cmake --build build --target $targetArgs -j $BuildJobs"
            if ($LASTEXITCODE -ne 0) {
                throw 'CMake build failed.'
            }

            # Persist updated per-target build state
            $nowIso = (Get-Date).ToUniversalTime().ToString('o')
            $targetHeadsMap = @{}
            $targetBuildUtcMap = @{}
            if ($savedState -and $savedState.targetHeads) {
                foreach ($prop in $savedState.targetHeads.PSObject.Properties) {
                    $targetHeadsMap[$prop.Name] = [string]$prop.Value
                }
            }
            if ($savedState -and $savedState.targetBuildUtc) {
                foreach ($prop in $savedState.targetBuildUtc.PSObject.Properties) {
                    $targetBuildUtcMap[$prop.Name] = [string]$prop.Value
                }
            }
            foreach ($t in $scopedTargets) {
                $targetHeadsMap[$t] = $currentHead
                $targetBuildUtcMap[$t] = $nowIso
            }
            $stateObj = [ordered]@{
                lastBuildUtc   = $nowIso
                targetHeads    = $targetHeadsMap
                targetBuildUtc = $targetBuildUtcMap
                cppHashes      = $currentCppHashes
            }
            $stateObj | ConvertTo-Json -Depth 4 | Set-Content -Path $buildStatePath -Encoding UTF8

            Write-Host '==> Build succeeded.' -ForegroundColor Green
        }
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
    try { Stop-Transcript | Out-Null } catch {}
    if (Test-Path $LogFile) {
        Copy-Item -Path $LogFile -Destination $LatestLogFile -Force -ErrorAction SilentlyContinue
        Write-Host "==> Full log saved to: $LatestLogFile (and $LogFile)" -ForegroundColor Cyan
    }
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
