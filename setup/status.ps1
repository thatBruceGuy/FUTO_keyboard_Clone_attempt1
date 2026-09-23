<#
    status.ps1

    Answers "where am I?" in one screen: which stages of the project are done,
    and the exact next command to run. Read-only, changes nothing.

    Usage:  powershell -ExecutionPolicy Bypass -File .\setup\status.ps1
#>

param(
    [string]$Target = "C:\Users\Bruce\Documents\ClaudeCode\FUTO-keyboard-clone"
)

$ErrorActionPreference = 'Continue'
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

function Mark($done) {
    if ($done -eq $true)  { return '[x]' }
    if ($done -eq $false) { return '[ ]' }
    return '[?]'
}

# --- Stage 1: prerequisites -------------------------------------------------
$prereqFail = $null
$verifier = Join-Path $here 'verify-prereqs.ps1'
if (Test-Path $verifier) {
    & $verifier -NoPause 6>$null | Out-Null       # Write-Host goes to stream 6
    $prereqFail = $LASTEXITCODE
}
$stage1 = if ($null -eq $prereqFail) { $null } else { $prereqFail -eq 0 }

# --- Stage 2: source cloned -------------------------------------------------
$stage2 = $false
$missingSubmodules = @()
if (Test-Path (Join-Path $Target '.git')) {
    Push-Location $Target
    $sub = git submodule status 2>$null
    $missingSubmodules = @($sub | Where-Object { $_ -match '^\s*-' })
    $stage2 = ($missingSubmodules.Count -eq 0)
    Pop-Location
}

# --- Stage 3: first build ---------------------------------------------------
$apk = $null
$apkDir = Join-Path $Target 'build\outputs\apk\unstable\debug'
if (Test-Path $apkDir) {
    $apk = Get-ChildItem $apkDir -Filter *.apk -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime | Select-Object -Last 1
}
$stage3 = [bool]$apk

# --- Stage 4: installed on the phone ---------------------------------------
$stage4 = $null
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if ($env:ANDROID_HOME) { $adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe' }
if (Test-Path $adb) {
    $devices = @(& $adb devices 2>$null | Select-String -Pattern "`tdevice$")
    if ($devices.Count -ge 1) {
        $pkgs = & $adb shell pm list packages 2>$null
        $stage4 = [bool]($pkgs | Select-String -SimpleMatch 'org.futo.inputmethod.latin')
    }
}

# --- Report -----------------------------------------------------------------
Write-Host ''
Write-Host 'FUTO Keyboard fork - project status' -ForegroundColor Cyan
Write-Host ''
Write-Host ("  {0} 1. Prerequisites installed" -f (Mark $stage1))
Write-Host ("  {0} 2. Source cloned with submodules" -f (Mark $stage2))
Write-Host ("  {0} 3. First build produced an APK" -f (Mark $stage3))
Write-Host ("  {0} 4. Installed on the phone" -f (Mark $stage4))
Write-Host ''

if ($stage1 -eq $false) {
    Write-Host "Stage 1 incomplete: $prereqFail check(s) failing." -ForegroundColor Yellow
    # The verifier writes its report to the first of these it can use.
    $report = $null
    foreach ($d in @([Environment]::GetFolderPath('Desktop'), $env:USERPROFILE, $env:TEMP, $here, (Get-Location).Path)) {
        if ([string]::IsNullOrWhiteSpace($d)) { continue }
        $c = Join-Path $d 'futo-prereq-report.txt'
        if (Test-Path $c) { $report = $c; break }
    }
    if ($report) {
        Write-Host 'Failing checks:' -ForegroundColor Yellow
        Select-String -Path $report -Pattern '\bFAIL\b' |
            Where-Object { $_.Line -notmatch '^\s*PASS\s+\d' } |
            ForEach-Object { Write-Host "  $($_.Line.Trim())" }
    }
    Write-Host ''
}
if ($stage2 -eq $false -and (Test-Path (Join-Path $Target '.git')) -and $missingSubmodules.Count -gt 0) {
    Write-Host 'Submodules not populated:' -ForegroundColor Yellow
    $missingSubmodules | ForEach-Object { Write-Host "  $($_.Trim())" }
    Write-Host ''
}
if ($stage3) { Write-Host "Latest APK: $($apk.FullName)" -ForegroundColor DarkGray; Write-Host '' }

# --- Next command -----------------------------------------------------------
Write-Host 'Next:' -ForegroundColor Green
if     ($null -eq $stage1)  { Write-Host "  verify-prereqs.ps1 is missing from $here. Re-download the setup scripts." }
elseif ($stage1 -eq $false) { Write-Host "  & `"$here\install-prereqs.ps1`"" }
elseif ($stage2 -eq $false) { Write-Host "  & `"$here\bootstrap.ps1`"" }
elseif ($stage3 -eq $false) { Write-Host "  cd `"$Target`"; .\gradlew.bat assembleUnstableDebug" }
elseif ($stage4 -ne $true)  { Write-Host "  cd `"$Target`"; adb install -r `"$($apk.FullName)`"" }
else {
    Write-Host '  Setup is complete. Tell Claude you are ready for the first spacing experiment.'
}
Write-Host ''
