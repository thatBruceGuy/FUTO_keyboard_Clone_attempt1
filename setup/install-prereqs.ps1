<#
    install-prereqs.ps1

    Installs the pieces that are easy to miss in the Android Studio GUI:
    Temurin JDK 21, Build-Tools 35, NDK 28.2.13676358 and CMake.
    Then applies the two git settings and re-runs verification.

    Usage:  powershell -ExecutionPolicy Bypass -File .\setup\install-prereqs.ps1

    Safe to rerun. Anything already present is left alone.
#>

param(
    [switch]$SkipJdk,
    [switch]$SkipSdk,
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Continue'
function Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Note($t) { Write-Host "    $t" -ForegroundColor DarkGray }
function Warn($t) { Write-Host "    $t" -ForegroundColor Yellow }

# The exact versions this project needs. The NDK is pinned in build.gradle,
# so no other version will do. CMakeLists.txt requires CMake 3.22 or newer.
$NdkVersion       = '28.2.13676358'
$BuildToolsVersion= '35.0.0'
$CmakeVersion     = '3.22.1'

# ------------------------------------------------------------------ JDK 21
if (-not $SkipJdk) {
    Step 'Temurin JDK 21'

    function Find-Jdk21 {
        $roots = @(
            "$env:ProgramFiles\Eclipse Adoptium",
            "${env:ProgramFiles(x86)}\Eclipse Adoptium",
            "$env:ProgramFiles\Java",
            "$env:LOCALAPPDATA\Programs\Eclipse Adoptium"
        ) | Where-Object { $_ -and (Test-Path $_) }
        foreach ($r in $roots) {
            $hit = Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match 'jdk-?21' -and (Test-Path (Join-Path $_.FullName 'bin\java.exe')) } |
                   Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
        return $null
    }

    $jdk = Find-Jdk21
    if ($jdk) {
        Note "already installed: $jdk"
    } else {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Note 'installing via winget, accept any elevation prompt'
            winget install --id EclipseAdoptium.Temurin.21.JDK --exact `
                           --accept-source-agreements --accept-package-agreements
            $jdk = Find-Jdk21
        } else {
            Warn 'winget not available on this machine.'
        }
    }

    if ($jdk) {
        [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk, 'User')
        $env:JAVA_HOME = $jdk          # so the verification below sees it now
        Note "JAVA_HOME -> $jdk"
        Note 'Open a new PowerShell window for this to apply to future sessions.'
    } else {
        Warn 'JDK 21 not installed. Download it from https://adoptium.net (Temurin 21, Windows x64),'
        Warn 'install it, then set JAVA_HOME to its folder and rerun this script.'
    }
}

# ------------------------------------------------------------ SDK packages
if (-not $SkipSdk) {
    Step 'Android SDK packages'

    $sdk = if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) { $env:ANDROID_HOME }
           else { "$env:LOCALAPPDATA\Android\Sdk" }

    if (-not (Test-Path $sdk)) {
        Warn "No Android SDK at $sdk. Open Android Studio and finish its setup wizard first."
    } else {
        Note "SDK: $sdk"
        $sm = Get-ChildItem (Join-Path $sdk 'cmdline-tools') -Recurse -Filter 'sdkmanager.bat' `
                            -ErrorAction SilentlyContinue | Select-Object -First 1

        if (-not $sm) {
            Warn 'Android SDK Command-line Tools are not installed, and they are needed to install'
            Warn 'the rest without hunting through checkboxes. Install them once:'
            Warn '  Android Studio > Settings > Languages and Frameworks > Android SDK > SDK Tools'
            Warn '  tick "Android SDK Command-line Tools (latest)" > Apply'
            Warn 'Then rerun this script.'
        } else {
            Note "sdkmanager: $($sm.FullName)"
            $packages = @(
                "build-tools;$BuildToolsVersion",
                "ndk;$NdkVersion",
                "cmake;$CmakeVersion"
            )
            foreach ($p in $packages) { Note "installing $p" }

            # sdkmanager asks for licence acceptance on first use.
            $yes = (("y") * 30) -join "`n"
            $yes | & $sm.FullName @packages
            if ($LASTEXITCODE -ne 0) {
                Warn "sdkmanager exited with code $LASTEXITCODE."
                Warn 'If it complains about licences, run this once and answer y:'
                Warn "  & '$($sm.FullName)' --licenses"
            }
        }
    }
}

# --------------------------------------------------------------- git config
Step 'Git settings'
git config --global core.longpaths true
git config --global core.autocrlf false
Note 'core.longpaths=true, core.autocrlf=false'

# ------------------------------------------------------------ Re-verify
if (-not $SkipVerify) {
    $verifier = Join-Path $PSScriptRoot 'verify-prereqs.ps1'
    if (Test-Path $verifier) {
        Step 'Re-running verification'
        & $verifier -NoPause
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nAll checks pass. Next: .\bootstrap.ps1" -ForegroundColor Green
        } else {
            Write-Host "`n$LASTEXITCODE check(s) still failing. See the fixes above." -ForegroundColor Red
        }
    } else {
        Warn "verify-prereqs.ps1 not found next to this script."
    }
}
