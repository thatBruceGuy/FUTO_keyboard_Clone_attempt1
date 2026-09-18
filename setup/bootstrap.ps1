# Bootstraps a personal FUTO Keyboard fork on Windows.
# Run from any directory in PowerShell after installing the items in SETUP.md.

$ErrorActionPreference = "Stop"
$Target   = "C:\Users\Bruce\Documents\ClaudeCode\FUTO-keyboard-clone"
$Upstream = "https://github.com/futo-org/android-keyboard.git"
$Origin   = "https://github.com/thatBruceGuy/FUTO_keyboard_Clone_attempt1.git"

function Require($name, $probe) {
    try { & $probe | Out-Null; Write-Host "ok    $name" }
    catch { Write-Host "MISSING $name"; $script:missing = $true }
}

$missing = $false
Require "git"      { git --version }
Require "git-lfs"  { git lfs version }
Require "python"   { python --version }
Require "java"     { java -version 2>&1 }
if (-not $env:ANDROID_HOME -and -not (Test-Path "$env:LOCALAPPDATA\Android\Sdk")) {
    Write-Host "MISSING Android SDK (set ANDROID_HOME or install via Android Studio)"; $missing = $true
} else { Write-Host "ok    Android SDK" }
if ($missing) { throw "Install the missing prerequisites listed in SETUP.md, then rerun." }

git config --global core.longpaths true
git config --global core.autocrlf false
git lfs install

if (Test-Path $Target) {
    Write-Host "Target exists, skipping clone: $Target"
} else {
    git clone --recursive $Upstream $Target
}

Set-Location $Target
$remotes = git remote
if ($remotes -notcontains "upstream") { git remote rename origin upstream }
if ($remotes -notcontains "origin")   { git remote add origin $Origin }
git fetch upstream --tags
git submodule update --init --recursive

if (-not (Test-Path "local.properties")) {
    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
    "sdk.dir=" + ($sdk -replace '\\', '\\\\' -replace ':', '\:') | Set-Content local.properties
    Write-Host "wrote local.properties pointing at $sdk"
}

Write-Host ""
Write-Host "Ready. Next: .\gradlew.bat assembleUnstableDebug"
