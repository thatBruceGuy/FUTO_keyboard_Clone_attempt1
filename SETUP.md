# Personal FUTO Keyboard fork: Windows setup

Target directory: `C:\Users\Bruce\Documents\ClaudeCode\FUTO-keyboard-clone`

Upstream source: https://github.com/futo-org/android-keyboard (mirror of https://gitlab.futo.org/keyboard/latinime).
License: FUTO Source First License 1.1-kb. Personal, non-commercial use and modification are allowed.
Do not redistribute a build with the payment feature or FUTO notices removed.

## 1. Prerequisite downloads

Install these in order. Versions are the ones the upstream build file pins.

| # | Item | Version | Where | Notes |
|---|------|---------|-------|-------|
| 1 | Git for Windows | latest | https://git-scm.com/download/win | Tick "Enable symbolic links" and choose the "checkout as-is, commit as-is" line-ending option. |
| 2 | Git LFS | latest | https://git-lfs.com | Needed for the swipe-model submodule hosted on Hugging Face. Run `git lfs install` once. |
| 3 | Python 3 | 3.10 or newer | https://www.python.org/downloads/windows/ | Tick "Add python.exe to PATH". Gradle calls `python` for locale and resource-bundle tasks. |
| 4 | Android Studio | latest stable | https://developer.android.com/studio | Provides the JDK, SDK Manager, and Gradle integration. |
| 5 | Android SDK Platform 35 | 35 | Android Studio > SDK Manager > SDK Platforms | `compileSdk 35`, `targetSdk 35`. |
| 6 | Android SDK Build-Tools | 35.x | SDK Manager > SDK Tools | |
| 7 | Android NDK | 28.2.13676358 | SDK Manager > SDK Tools > "Show Package Details" > NDK (Side by side) | The exact version is pinned in `build.gradle`. Other versions fail with "NDK not found". |
| 8 | CMake | 3.22.1 or newer | SDK Manager > SDK Tools | Builds the whisper.cpp, GGML, MOZC and RIME native code. |
| 9 | Android SDK Platform-Tools | latest | SDK Manager > SDK Tools | Gives you `adb` for installing on your phone. |

Gradle 8.14.3 and Kotlin 2.1.0 are fetched automatically by the wrapper. No manual download.
JDK: Android Studio bundles JetBrains Runtime 21, which works. If you build from a terminal, set `JAVA_HOME` to that JDK
(usually `C:\Program Files\Android\Android Studio\jbr`).

Disk: budget about 15 GB. The SDK and NDK are around 6 GB, the source with submodules about 2 GB, and the native build output several GB more.

## 1b. Verify the prerequisites

After installing the items above, confirm all five steps landed correctly:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup\verify-prereqs.ps1
```

It checks every item in the table plus the git settings below, prints a PASS/WARN/FAIL table
with a fix for each problem, and exits with the number of failures. It installs nothing and
changes nothing. A WARN is advisory; a FAIL blocks the build.

## 2. One-time Windows settings

Run in an elevated PowerShell:

```powershell
git config --global core.longpaths true
git config --global core.autocrlf false
git lfs install
```

Long paths matter because the native test sources exceed 100 characters below the repo root, and the Gradle build directory adds more.

## 3. Clone and wire up remotes

Run `setup\bootstrap.ps1` from this repository, or do it by hand:

```powershell
cd C:\Users\Bruce\Documents\ClaudeCode
git clone --recursive https://github.com/futo-org/android-keyboard.git FUTO-keyboard-clone
cd FUTO-keyboard-clone
git remote rename origin upstream
git remote add origin https://github.com/thatBruceGuy/FUTO_keyboard_Clone_attempt1.git
```

Rules that come from the upstream build script:

- Do not use `--depth 1`. Version code is `git rev-list --count master` and version name is `git describe --tags`. A shallow clone has neither.
- Keep a local branch named `master` that tracks `upstream/master`. Do your work on another branch, but leave `master` in place.
- Do not delete the tags.

## 4. Local config files (not committed)

`local.properties` in the project root, created by Android Studio on first open, or by hand:

```
sdk.dir=C\:\\Users\\Bruce\\AppData\\Local\\Android\\Sdk
```

Optional `keystore.properties` for a release build signed with your own key. Without it, release builds use the checked-in debug keystore.

```
storeFile=..\\my-release-key.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Do not create `crashreporting.properties`. Its absence disables ACRA crash upload.

## 5. First build

```powershell
.\gradlew.bat assembleUnstableDebug
```

Expect 20 to 60 minutes the first time, most of it compiling the native layer. The APK lands in `build\outputs\apk\unstable\debug\`.

Install with the phone in USB debugging mode:

```powershell
adb install -r build\outputs\apk\unstable\debug\*.apk
```

## 6. Fork changes to make after the first successful build

These are the edits that turn the upstream tree into a private fork. They are not applied yet.

1. Change `applicationId` in `build.gradle` so your build installs beside the official app instead of over it.
2. Set `UPDATE_CHECKING` to `false` in the `unstable` and `stable` flavors so the app stops pointing you at FUTO's download page.
3. Add your own signing key via `keystore.properties`.
4. Optionally silence the payment reminder for your own device only.

## 7. Known Windows snags

- Gradle runs `python`, not `python3`, on Windows. The Microsoft Store "python" stub will hijack that name if real Python is not on PATH first. Disable the stub under Settings > Apps > App execution aliases if `python --version` opens the Store.
- Antivirus real-time scanning of the build directory can double compile times. Exclude the project folder if you can.
- If CMake reports a missing Ninja, install the "CMake" package from the SDK Manager rather than a standalone CMake; the SDK one bundles Ninja.
