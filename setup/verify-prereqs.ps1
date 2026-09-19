<#
    verify-prereqs.ps1

    Verifies the five prerequisite installs for the personal FUTO Keyboard fork.
    Read-only: installs nothing, changes nothing, needs no administrator rights.

    Usage:   powershell -ExecutionPolicy Bypass -File .\setup\verify-prereqs.ps1
    Output:  a PASS/WARN/FAIL table, then a summary and a fix list.
#>

param(
    # Skip the "press Enter" pause. Use when running inside a window you control.
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$results = @()
$fixes   = @()
$out     = New-Object System.Collections.Generic.List[string]

# Every line goes to the console AND to $out, so a report file can be written
# even when the console window closes the instant the script ends.
function Say {
    param([string]$Text = '', $Color)
    $script:out.Add($Text)
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Add-Result {
    param($Step, $Check, $Status, $Detail, $Fix)
    $script:results += [PSCustomObject]@{
        Step = $Step; Check = $Check; Status = $Status; Detail = $Detail
    }
    if ($Fix) { $script:fixes += "[$Step] $Check -> $Fix" }
}

function Get-Cmd($name) { Get-Command $name -ErrorAction SilentlyContinue }

function Get-GitConfig($key) {
    $v = & git config --get $key 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($v | Select-Object -First 1)
}

Say ''
Say 'FUTO Keyboard fork - prerequisite verification' Cyan
Say "Run at $(Get-Date -Format 'yyyy-MM-dd HH:mm') on $env:COMPUTERNAME" DarkGray
Say ''

# ---------------------------------------------------------------- Step 1: Git
$git = Get-Cmd git
if (-not $git) {
    Add-Result 1 'Git installed' 'FAIL' 'git not found on PATH' `
        'Install Git for Windows from https://git-scm.com/download/win'
} else {
    $gv = (& git --version) -replace 'git version ', ''
    Add-Result 1 'Git installed' 'PASS' "$gv  ($($git.Source))"

    # The installer's "Enable symbolic links" option writes core.symlinks=true.
    # The FUTO tree contains no symlinks today, so this is advisory, not fatal.
    $sym = Get-GitConfig 'core.symlinks'
    if ($sym -eq 'true') {
        Add-Result 1 'Symlink support' 'PASS' 'core.symlinks=true'
    } else {
        $shown = if ($sym) { "core.symlinks=$sym" } else { 'core.symlinks not set' }
        Add-Result 1 'Symlink support' 'WARN' "$shown (no symlinks in this repo, so non-blocking)" `
            'git config --global core.symlinks true'
    }
}

# ------------------------------------------------------------ Step 2: Git LFS
$lfsOk = $false
if ($git) {
    $lfsVer = & git lfs version 2>$null
    if ($LASTEXITCODE -eq 0 -and $lfsVer) {
        $lfsOk = $true
        Add-Result 2 'Git LFS installed' 'PASS' ($lfsVer | Select-Object -First 1)
    } else {
        Add-Result 2 'Git LFS installed' 'FAIL' 'git lfs not available' `
            'Install from https://git-lfs.com then run: git lfs install'
    }
}
if ($lfsOk) {
    # "git lfs install" writes the smudge/clean filters into the global config.
    $clean = & git config --global --get filter.lfs.clean 2>$null
    if ($LASTEXITCODE -eq 0 -and $clean) {
        Add-Result 2 'git lfs install run' 'PASS' "filter.lfs.clean = $clean"
    } else {
        Add-Result 2 'git lfs install run' 'FAIL' 'LFS filters missing from global config' `
            'Run: git lfs install'
    }
}

# ------------------------------------------------------------- Step 3: Python
# Check the resolved path BEFORE running python, because the Microsoft Store
# stub opens the Store window when executed.
$py = Get-Cmd python
if (-not $py) {
    Add-Result 3 'Python on PATH as "python"' 'FAIL' 'python not found' `
        'Install Python 3.10+ from python.org and tick "Add python.exe to PATH"'
} elseif ($py.Source -like '*\WindowsApps\*') {
    # Both the Store's placeholder stub and a real Store install resolve here.
    # Running it would pop the Store window, so inspect the registry instead.
    $reg = @()
    foreach ($hive in 'HKLM:\SOFTWARE\Python\PythonCore', 'HKCU:\SOFTWARE\Python\PythonCore') {
        if (Test-Path $hive) {
            $reg += Get-ChildItem $hive -ErrorAction SilentlyContinue | ForEach-Object {
                $ip = (Get-ItemProperty (Join-Path $_.PSPath 'InstallPath') -ErrorAction SilentlyContinue).'(default)'
                if ($ip) { "$($_.PSChildName) at $ip" }
            }
        }
    }
    if ($reg) {
        Add-Result 3 'Python on PATH as "python"' 'FAIL' `
            "PATH resolves to the Store alias ($($py.Source)) but a real Python exists: $($reg -join '; ')" `
            'Settings > Apps > Advanced app settings > App execution aliases: turn OFF python.exe and python3.exe, then reopen PowerShell'
    } else {
        Add-Result 3 'Python on PATH as "python"' 'FAIL' "Microsoft Store alias at $($py.Source), no real Python installed" `
            'Install Python 3.10+ from python.org with "Add python.exe to PATH" ticked, and turn OFF the python.exe app execution alias'
    }
} else {
    $pv = (& python --version 2>&1) | Select-Object -First 1
    $m  = [regex]::Match([string]$pv, '(\d+)\.(\d+)\.(\d+)')
    if ($m.Success) {
        $maj = [int]$m.Groups[1].Value; $min = [int]$m.Groups[2].Value
        if ($maj -gt 3 -or ($maj -eq 3 -and $min -ge 10)) {
            Add-Result 3 'Python 3.10 or newer' 'PASS' "$pv  ($($py.Source))"
        } else {
            Add-Result 3 'Python 3.10 or newer' 'FAIL' "$pv is too old" `
                'Install Python 3.10 or newer from python.org'
        }
    } else {
        Add-Result 3 'Python 3.10 or newer' 'FAIL' "could not parse version from '$pv'" `
            'Reinstall Python from python.org'
    }
}

# ---------------------------------------------------- Step 4: Android Studio
$studioDir = $null
$candidates = @(
    "$env:ProgramFiles\Android\Android Studio",
    "${env:ProgramFiles(x86)}\Android\Android Studio",
    "$env:LOCALAPPDATA\Programs\Android Studio",
    "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\AndroidStudio"
)
foreach ($c in $candidates) {
    if ($c -and (Test-Path (Join-Path $c 'bin\studio64.exe'))) { $studioDir = $c; break }
}
if (-not $studioDir) {
    # JetBrains Toolbox nests builds one level deeper.
    $tb = "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\AndroidStudio"
    if (Test-Path $tb) {
        $hit = Get-ChildItem $tb -Recurse -Filter studio64.exe -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { $studioDir = Split-Path (Split-Path $hit.FullName -Parent) -Parent }
    }
}
if ($studioDir) {
    Add-Result 4 'Android Studio installed' 'PASS' $studioDir
    $jbr = Join-Path $studioDir 'jbr\bin\java.exe'
    if (Test-Path $jbr) {
        $jv = (& $jbr -version 2>&1) | Select-Object -First 1
        Add-Result 4 'Bundled JDK (jbr)' 'PASS' "$jv"
    } else {
        Add-Result 4 'Bundled JDK (jbr)' 'WARN' 'jbr not found under the Studio directory' `
            'Builds from a terminal need JAVA_HOME pointing at a JDK 17+'
    }
} else {
    Add-Result 4 'Android Studio installed' 'FAIL' 'studio64.exe not found in the usual locations' `
        'Install from https://developer.android.com/studio'
}

# Terminal builds use JAVA_HOME, which is separate from Studio's bundled JDK.
if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $jhv = (& (Join-Path $env:JAVA_HOME 'bin\java.exe') -version 2>&1) | Select-Object -First 1
    $mj  = [regex]::Match([string]$jhv, '"(\d+)')
    if ($mj.Success -and [int]$mj.Groups[1].Value -ge 17) {
        Add-Result 4 'JAVA_HOME (terminal builds)' 'PASS' "$jhv"
    } else {
        $jhFix2 = if ($studioDir) { "Point JAVA_HOME at $studioDir\jbr" }
                  else { 'Point JAVA_HOME at a JDK 17 or newer' }
        Add-Result 4 'JAVA_HOME (terminal builds)' 'WARN' "$jhv is older than 17" $jhFix2
    }
} else {
    $jhFix = if ($studioDir) {
        "Set JAVA_HOME to $studioDir\jbr (only needed for gradlew from a terminal)"
    } else {
        'Install Android Studio, then set JAVA_HOME to its jbr directory (only needed for gradlew from a terminal)'
    }
    Add-Result 4 'JAVA_HOME (terminal builds)' 'WARN' 'not set or invalid' $jhFix
}

# ------------------------------------------- Step 5: SDK, NDK, CMake, tools
$sdk = $null
$sdkSource = ''
if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
    $sdk = $env:ANDROID_HOME; $sdkSource = 'ANDROID_HOME'
} elseif ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
    $sdk = $env:ANDROID_SDK_ROOT; $sdkSource = 'ANDROID_SDK_ROOT'
} elseif (Test-Path 'local.properties') {
    $line = Select-String -Path 'local.properties' -Pattern '^\s*sdk\.dir\s*=' -ErrorAction SilentlyContinue
    if ($line) {
        $p = ($line.Line -split '=', 2)[1].Trim() -replace '\\\\', '\' -replace '\\:', ':'
        if (Test-Path $p) { $sdk = $p; $sdkSource = 'local.properties' }
    }
}
if (-not $sdk -and (Test-Path "$env:LOCALAPPDATA\Android\Sdk")) {
    $sdk = "$env:LOCALAPPDATA\Android\Sdk"; $sdkSource = 'default location'
}

if (-not $sdk) {
    Add-Result 5 'Android SDK located' 'FAIL' 'no SDK found' `
        'Open Android Studio once to install the SDK, or set ANDROID_HOME'
} else {
    Add-Result 5 'Android SDK located' 'PASS' "$sdk  (via $sdkSource)"

    # Platform 35
    if (Test-Path (Join-Path $sdk 'platforms\android-35')) {
        Add-Result 5 'SDK Platform 35' 'PASS' 'platforms\android-35'
    } else {
        $have = (Get-ChildItem (Join-Path $sdk 'platforms') -Directory -ErrorAction SilentlyContinue |
                 ForEach-Object Name) -join ', '
        Add-Result 5 'SDK Platform 35' 'FAIL' "missing. Present: $have" `
            'SDK Manager > SDK Platforms > Android 15.0 (API 35)'
    }

    # Build-Tools 35.x
    $bt = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -like '35.*' }
    if ($bt) {
        Add-Result 5 'Build-Tools 35.x' 'PASS' (($bt | ForEach-Object Name) -join ', ')
    } else {
        $have = (Get-ChildItem (Join-Path $sdk 'build-tools') -Directory -ErrorAction SilentlyContinue |
                 ForEach-Object Name) -join ', '
        Add-Result 5 'Build-Tools 35.x' 'FAIL' "missing. Present: $have" `
            'SDK Manager > SDK Tools > Android SDK Build-Tools 35'
    }

    # Platform-Tools / adb
    $adb = Join-Path $sdk 'platform-tools\adb.exe'
    if (Test-Path $adb) {
        $av = (& $adb version 2>&1) | Select-Object -First 1
        Add-Result 5 'Platform-Tools (adb)' 'PASS' "$av"
    } else {
        Add-Result 5 'Platform-Tools (adb)' 'FAIL' 'adb.exe not found' `
            'SDK Manager > SDK Tools > Android SDK Platform-Tools'
    }

    # NDK - the build pins one exact version
    $needNdk = '28.2.13676358'
    $ndkPath = Join-Path $sdk "ndk\$needNdk"
    if (Test-Path $ndkPath) {
        Add-Result 5 "NDK $needNdk" 'PASS' $ndkPath
    } else {
        $have = (Get-ChildItem (Join-Path $sdk 'ndk') -Directory -ErrorAction SilentlyContinue |
                 ForEach-Object Name) -join ', '
        if (-not $have) { $have = 'none' }
        Add-Result 5 "NDK $needNdk" 'FAIL' "missing. Present: $have" `
            "SDK Manager > SDK Tools > tick 'Show Package Details' > NDK (Side by side) > $needNdk"
    }

    # CMake plus the Ninja generator it ships with
    $cm = Get-ChildItem (Join-Path $sdk 'cmake') -Directory -ErrorAction SilentlyContinue |
          Where-Object { Test-Path (Join-Path $_.FullName 'bin\cmake.exe') }
    if ($cm) {
        $newest = $cm | Sort-Object Name | Select-Object -Last 1
        $hasNinja = Test-Path (Join-Path $newest.FullName 'bin\ninja.exe')
        if ($hasNinja) {
            Add-Result 5 'CMake + Ninja (from SDK)' 'PASS' $newest.Name
        } else {
            Add-Result 5 'CMake + Ninja (from SDK)' 'WARN' "$($newest.Name) has no bundled ninja.exe" `
                'Install CMake via the SDK Manager rather than standalone; it bundles Ninja'
        }
    } else {
        Add-Result 5 'CMake + Ninja (from SDK)' 'FAIL' 'no CMake under the SDK' `
            'SDK Manager > SDK Tools > CMake'
    }
}

# --------------------------------------------------- Extras worth knowing now
$lp = Get-GitConfig 'core.longpaths'
if ($lp -eq 'true') {
    Add-Result 'extra' 'core.longpaths' 'PASS' 'true'
} else {
    Add-Result 'extra' 'core.longpaths' 'WARN' 'not enabled; deep native test paths can fail to check out' `
        'git config --global core.longpaths true'
}

$crlf = Get-GitConfig 'core.autocrlf'
if ($crlf -eq 'false') {
    Add-Result 'extra' 'core.autocrlf' 'PASS' 'false'
} else {
    $shown = if ($crlf) { $crlf } else { 'not set' }
    Add-Result 'extra' 'core.autocrlf' 'WARN' "$shown; line-ending rewrites can break gradlew and shell scripts" `
        'git config --global core.autocrlf false'
}

$driveLetter = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { 'C' }
try {
    $drv  = Get-PSDrive $driveLetter -ErrorAction Stop
    $free = [math]::Round($drv.Free / 1GB, 1)
    $label = "Free disk on ${driveLetter}:"
    if ($free -ge 15)     { Add-Result 'extra' $label 'PASS' "$free GB" }
    elseif ($free -ge 10) { Add-Result 'extra' $label 'WARN' "$free GB; 15 GB recommended" 'Free up space before the first build' }
    else                  { Add-Result 'extra' $label 'FAIL' "$free GB is not enough" 'Free up at least 15 GB' }
} catch {
    Add-Result 'extra' "Free disk on ${driveLetter}:" 'WARN' 'could not read the drive'
}

# ------------------------------------------------------------------- Report
$table = $results |
    Format-Table -AutoSize -Property Step, Check, Status, Detail |
    Out-String -Width 200
foreach ($line in ($table -split "`r?`n")) { Say $line }

$fail = @($results | Where-Object Status -eq 'FAIL').Count
$warn = @($results | Where-Object Status -eq 'WARN').Count
$pass = @($results | Where-Object Status -eq 'PASS').Count

Say ("PASS {0}    WARN {1}    FAIL {2}" -f $pass, $warn, $fail) Cyan
Say ''

if ($fixes.Count -gt 0) {
    Say 'Fixes:' Yellow
    foreach ($f in $fixes) { Say "  $f" }
    Say ''
}

if ($fail -eq 0) {
    Say 'All five prerequisite steps are satisfied. Next: run setup\bootstrap.ps1 to clone the source.' Green
} else {
    Say "$fail check(s) failed. Fix those, then rerun this script." Red
}
Say ''

# Write the report somewhere the user can still read it after the window closes.
$reportPath = $null
foreach ($dir in @([Environment]::GetFolderPath('Desktop'), $env:USERPROFILE, $env:TEMP, (Get-Location).Path)) {
    if ([string]::IsNullOrWhiteSpace($dir)) { continue }
    try {
        $candidate = Join-Path $dir 'futo-prereq-report.txt'
        $out -join [Environment]::NewLine | Out-File -FilePath $candidate -Encoding utf8 -ErrorAction Stop
        $reportPath = $candidate
        break
    } catch { continue }
}
if ($reportPath) {
    Write-Host "Report saved to: $reportPath" -ForegroundColor Cyan
    Write-Host 'Open that file and paste its contents back to Claude.' -ForegroundColor Cyan
} else {
    Write-Host 'Could not write a report file; copy the table above manually.' -ForegroundColor Yellow
}
Write-Host ''

# A window spawned by double-clicking or by "powershell -File" closes the moment
# this script ends, taking the table with it. Hold it open unless told not to.
if (-not $NoPause) {
    Write-Host 'Press Enter to close this window...' -ForegroundColor DarkGray
    try { [void](Read-Host) } catch { Start-Sleep -Seconds 30 }
}

exit $fail
