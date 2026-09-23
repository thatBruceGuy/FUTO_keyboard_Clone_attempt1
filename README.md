# FUTO Keyboard personal fork: project record

Everything produced in the cloud session for this project, plus the findings behind it.
This file is written to stand alone, so the backup is useful without the chat transcript.

Owner: Bruce. Repository: `thatBruceGuy/FUTO_keyboard_Clone_attempt1`.
Working branch: `claude/futo-keyboard-fork-roadblocks-m961iq`.

## Goal

Make a personal, non-commercial copy of FUTO Keyboard and experiment with the spacing between
keys and with alternative layouts, to see which changes improve typing.

## Licensing

Upstream is under the **FUTO Source First License 1.1-kb**. Relevant terms, quoted:

- "You may modify the software only for non-commercial purposes such as personal use for research,
  experiment, and testing ... hobby projects, amateur pursuits".
- "You may distribute the software or any part of its source code only if you do so free of charge
  for non-commercial purposes."
- "you may not remove or obscure any functionality in the software related to payment to the Licensor
  in any copy you distribute to others."
- Modified copies you distribute must carry "a prominent notice stating that you have modified the software".

A private fork for personal use is squarely permitted. Only the original AOSP LatinIME portion,
up to commit `d847619a2b48945465f840b8d81644fa455cc115`, is Apache 2.0. Everything FUTO added is not.
Contributing upstream needs a CLA, and the project asks that AI-generated pull requests not be submitted.

## Where the source lives

Primary: `https://gitlab.futo.org/keyboard/latinime` (registration closed).
Mirror used here: `https://github.com/futo-org/android-keyboard`.

Seven submodules across three hosts. All must be reachable to clone:

| Submodule path | Host |
|---|---|
| `libs` | gitlab.futo.org |
| `translations` | gitlab.futo.org |
| `java/assets/themes` | gitlab.futo.org |
| `java/res-large` | gitlab.futo.org |
| `voiceinput-shared/src/main/ml` | gitlab.futo.org |
| `java/assets/layouts` | github.com/futo-org (Apache 2.0) |
| `java/assets/futo-swipe` | huggingface.co, needs Git LFS |

## Toolchain, as pinned by the build files

| Item | Version | Source of the requirement |
|---|---|---|
| Gradle | 8.14.3 | `gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 8.10.1 | `build.gradle` |
| Kotlin | 2.1.0 | `build.gradle` |
| compileSdk / targetSdk | 35 | `build.gradle` |
| minSdk | 24 | `build.gradle` |
| NDK | 28.2.13676358 exactly | `ndkVersion` in `build.gradle` |
| CMake | 3.22 or newer | `cmake_minimum_required` in `native/jni/CMakeLists.txt` |
| Build tools | not pinned, so the AGP default for SDK 35 applies | absence of `buildToolsVersion` |
| Python | 3.10+ | two Gradle `Exec` tasks call `python` |

### The JDK trap, verified by testing

Gradle 8.14.3 **fails on JDK 25** with `Unsupported class file major version 69` as soon as a real
task runs. It works on JDK 21. This was confirmed by running `gradle compileJava` under both.

`java -version` and `gradle --version` both succeed on JDK 25, so the problem only appears during a
build. Recent Android Studio releases bundle JDK 25 as their JetBrains Runtime, so the bundled JDK
cannot build this project. Install Temurin JDK 21 and point `JAVA_HOME` at it. In Android Studio set
the Gradle JDK to 21 under Build, Execution, Deployment.

## Where the code to change lives

Verified against the upstream tree. Confirm line numbers before editing, since upstream moves.

**Key spacing**
- `java/src/org/futo/inputmethod/v2keyboard/KeyboardLayoutSet.kt` holds `gap: Float = 4.0f`, in dp.
  This single hardcoded default is the only source of key spacing. It is not a user setting.
- `java/src/org/futo/inputmethod/v2keyboard/LayoutEngine.kt` sets `horizontalGap = layoutParams.gap`
  and `verticalGap = layoutParams.gap * 2`. Also holds the `addGap` logic that centres short rows.
- `java/src/org/futo/inputmethod/keyboard/Key.kt` stores each key's gaps. Note that `hitBox` includes
  the gap, so touch targets stay contiguous when the visible key shrinks. `drawX` offsets by half the gap.
- `java/src/org/futo/inputmethod/keyboard/internal/KeyboardParams.java` holds the older gap and padding
  fields. The v2 engine zeroes them and handles gaps itself.
- `java/src/org/futo/inputmethod/v2keyboard/KeyboardSizingCalculator.kt` handles height, width, outer
  padding, split and one-handed sizing. These are already exposed as user settings per orientation.

**Layouts**
- `java/assets/layouts/` is the Apache-licensed submodule of YAML layout files, plus `mapping.yaml`
  (locale to layout) and `names.yaml` (display names).
- `java/src/org/futo/inputmethod/v2keyboard/Keyboard.kt` defines the YAML schema.
- `java/src/org/futo/inputmethod/v2keyboard/LayoutManager.kt` loads and parses them.
- `java/src/org/futo/inputmethod/latin/uix/settings/pages/DevLayoutEditor.kt` is a built-in editor in
  the app's developer settings. Paste layout YAML and test it on the device without rebuilding.

## Fork changes to make after the first successful build

1. Change `applicationId` from `org.futo.inputmethod.latin` so your build installs beside the official app.
2. Set `UPDATE_CHECKING` to `false` in the `unstable` and `stable` flavors, or the app points you at
   FUTO's download page.
3. Add your own signing key via `keystore.properties`. Without it, release builds use the checked-in
   debug keystore.
4. Do not create `crashreporting.properties`. Its absence keeps ACRA crash upload disabled.

## Build and install

```
.\gradlew.bat assembleUnstableDebug
adb install -r build\outputs\apk\unstable\debug\*.apk
```

The app module is the root project, so output lands at `build\outputs\apk\unstable\debug\`.
The first build takes 20 to 60 minutes, mostly compiling whisper.cpp, GGML, MOZC and RIME.

## Files in this backup

| File | What it does |
|---|---|
| `README.md` | This record |
| `SETUP.md` | Windows prerequisite list and one-time settings |
| `PROJECT_PROMPT.md` | The prompt to open a new session with, including a 24-item pre-flight checklist |
| `setup/status.ps1` | Prints which of the four project stages are done and the next command. Read-only |
| `setup/verify-prereqs.ps1` | Checks every prerequisite, writes a report, exits with the failure count |
| `setup/install-prereqs.ps1` | Installs JDK 21 and the three SDK packages, applies git settings |
| `setup/bootstrap.ps1` | Verifies, then clones the source and wires up remotes |
| `.gitignore` | Keeps local config, signing keys and build output out of git |

Run them in the order status, install, bootstrap. All four expect to sit in the same folder.

## Project stages

1. Prerequisites installed
2. Source cloned with all seven submodules
3. First build produces an APK
4. Keyboard installed on the phone

Then the experiments begin: a spacing sweep at 2, 4, 6 and 8 dp, splitting horizontal from vertical
spacing, then layout variants.

## Status at the time of this backup

Stage 1 was incomplete. Git, Git LFS, Python and Android Studio were installed and passing. Missing
were Temurin JDK 21, build tools 35, the pinned NDK, and CMake. Run `setup\status.ps1` for the
current picture.
