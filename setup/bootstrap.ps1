<#
    bootstrap.ps1

    Clones the FUTO Keyboard source and wires it up as a personal fork.
    Run after the prerequisites pass. See SETUP.md.

    Usage:  powershell -ExecutionPolicy Bypass -File .\setup\bootstrap.ps1
#>

param(
    [string]$Target   = "C:\Users\Bruce\Documents\ClaudeCode\FUTO-keyboard-clone",
    [string]$Upstream = "https://github.com/futo-org/android-keyboard.git",
    [string]$Origin   = "https://github.com/thatBruceGuy/FUTO_keyboard_Clone_attempt1.git",
    # Skip the prerequisite verification. Only for reruns after it already passed.
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

# ------------------------------------------------------------ Prerequisites
# Delegate to verify-prereqs.ps1 rather than repeating weaker checks here.
# It grades the JDK properly; a bare "java -version" succeeds on JDK 25,
# which cannot build this project.
if (-not $SkipVerify) {
    $verifier = Join-Path $PSScriptRoot 'verify-prereqs.ps1'
    if (Test-Path $verifier) {
        Step 'Verifying prerequisites'
        & $verifier -NoPause
        if ($LASTEXITCODE -ne 0) {
            throw "$LASTEXITCODE prerequisite check(s) failed. Fix them, then rerun. Pass -SkipVerify to override."
        }
    } else {
        Write-Warning "verify-prereqs.ps1 not found next to this script; skipping prerequisite checks."
    }
}

# ------------------------------------------------------------- Git settings
Step 'Applying git settings'
git config --global core.longpaths true   # deep native test paths exceed the old limit
git config --global core.autocrlf false   # avoid rewriting line endings in shell scripts
git lfs install | Out-Null

# -------------------------------------------------------------------- Clone
if (Test-Path (Join-Path $Target '.git')) {
    Step "Repository already present, skipping clone: $Target"
} else {
    Step "Cloning into $Target"
    Write-Host 'Submodules live on gitlab.futo.org, github.com and huggingface.co.' -ForegroundColor DarkGray
    Write-Host 'All three must be reachable. This takes a while.' -ForegroundColor DarkGray
    # No --depth: the build derives its version from the full history and tags.
    git clone --recursive $Upstream $Target
    if ($LASTEXITCODE -ne 0) { throw "Clone failed." }
}

Set-Location $Target

# ------------------------------------------------------------------ Remotes
# Re-query after each change; a stale list silently skips adding origin.
Step 'Configuring remotes'
if ((git remote) -notcontains 'upstream') {
    if ((git remote) -contains 'origin') {
        git remote rename origin upstream
    } else {
        git remote add upstream $Upstream
    }
}
if ((git remote) -notcontains 'origin') {
    git remote add origin $Origin
} else {
    git remote set-url origin $Origin
}
git remote -v

# --------------------------------------------------------------- Submodules
Step 'Ensuring submodules are populated'
git submodule update --init --recursive
$stale = @(git submodule status | Where-Object { $_ -match '^\s*-' })
if ($stale.Count -gt 0) {
    Write-Warning "These submodules are not populated:"
    $stale | ForEach-Object { Write-Host "  $_" }
    Write-Warning 'Rerun this script, or check that gitlab.futo.org and huggingface.co are reachable.'
}

# ------------------------------------------------------- Version provenance
# versionCode comes from "git rev-list --count master" and versionName from
# "git describe --tags", so both must resolve or the build fails.
Step 'Checking version sources'
git fetch upstream --tags 2>&1 | Out-Null
if ((git branch --list master) -notmatch 'master') {
    git branch --track master upstream/master 2>&1 | Out-Null
}
$count = git rev-list --first-parent --count master 2>$null
$desc  = git describe --tags 2>$null
if ($count) { Write-Host "  versionCode source: $count commits on master" }
else        { Write-Warning '  master branch missing; versionCode will fail' }
if ($desc)  { Write-Host "  versionName source: $desc" }
else        { Write-Warning '  no tags found; versionName will fail' }

# ---------------------------------------------------------- local.properties
Step 'Writing local.properties'
if (Test-Path 'local.properties') {
    Write-Host '  already exists, leaving it alone'
} else {
    $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
    'sdk.dir=' + ($sdk -replace '\\', '\\' -replace ':', '\:') | Set-Content 'local.properties' -Encoding ascii
    Write-Host "  sdk.dir -> $sdk"
}

Step 'Ready'
Write-Host 'Next: .\gradlew.bat assembleUnstableDebug' -ForegroundColor Green
Write-Host 'First build compiles the native code and can take 20 to 60 minutes.' -ForegroundColor DarkGray
