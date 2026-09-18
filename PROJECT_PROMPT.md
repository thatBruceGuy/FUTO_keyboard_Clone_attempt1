# Project prompt: personal FUTO Keyboard fork for key spacing and layout experiments

Copy everything below this line into the first message of a new Claude Code session opened in
`C:\Users\Bruce\Documents\ClaudeCode\FUTO-keyboard-clone`.

---

You are working in my personal fork of FUTO Keyboard, an Android keyboard app written in Kotlin,
Java and C++ and built with Gradle. The working directory is
`C:\Users\Bruce\Documents\ClaudeCode\FUTO-keyboard-clone`. The `upstream` remote is FUTO's GitHub
mirror. The `origin` remote is my repository `thatBruceGuy/FUTO_keyboard_Clone_attempt1`.

## Goal

Experiment with the spacing between keys and with alternative keyboard layouts, then measure whether
each change improves my typing experience on my own phone. Every experiment must produce an installable
debug APK that I can try, and a short note recording what changed and what I observed.

## Ground rules

- This is a private, non-commercial fork under the FUTO Source First License 1.1-kb. Do not remove
  the payment feature, license notices or copyright notices. Do not prepare anything for redistribution.
- Never commit `local.properties`, `keystore.properties`, `crashreporting.properties` or any `.jks` file.
- Do not touch the `master` branch or delete tags. The build reads the version from
  `git rev-list --count master` and `git describe --tags`.
- Work on a branch named `experiments/<short-name>`, one branch per experiment. Push to `origin`
  only, never to `upstream`.
- Prefer the smallest change that tests the idea. Do not refactor unrelated code.
- Build with `.\gradlew.bat assembleUnstableDebug` and install with
  `adb install -r build\outputs\apk\unstable\debug\*.apk`. Report build failures verbatim.
- Ask before any change that alters the application ID, signing, or dependencies.

## Pre-flight checklist

Run every check below before starting any experiment. Report the result of each as a table with
columns Check, Command, Result. Stop and tell me what to install or fix if any check fails.
Do not begin editing code until every row passes.

| # | Check | How to verify | Pass condition |
|---|-------|---------------|----------------|
| 1 | Git | `git --version` | Prints a version |
| 2 | Git long paths | `git config --get core.longpaths` | `true` |
| 3 | Git LFS | `git lfs version` | Prints a version |
| 4 | Python on PATH | `python --version` | Prints 3.10 or newer and does not open the Microsoft Store |
| 5 | JDK | `java -version` | Prints 17 or newer |
| 6 | JAVA_HOME | `echo $env:JAVA_HOME` | Points at a JDK directory containing `bin\java.exe` |
| 7 | Android SDK location | `Get-Content local.properties` | `sdk.dir` points at an existing directory |
| 8 | SDK Platform 35 | `Test-Path "$sdk\platforms\android-35"` | `True` |
| 9 | Build-Tools 35 | `Get-ChildItem "$sdk\build-tools"` | A `35.*` directory exists |
| 10 | NDK exact version | `Test-Path "$sdk\ndk\28.2.13676358"` | `True` |
| 11 | CMake from SDK | `Get-ChildItem "$sdk\cmake"` | At least one version directory with `bin\cmake.exe` and `bin\ninja.exe` |
| 12 | Platform-Tools | `adb version` | Prints a version |
| 13 | Repository is not shallow | `git rev-parse --is-shallow-repository` | `false` |
| 14 | Tags present | `git describe --tags` | Prints a tag-based version, not an error |
| 15 | master branch exists | `git branch --list master` | Lists `master` |
| 16 | Remotes | `git remote -v` | `upstream` is futo-org/android-keyboard, `origin` is my repo |
| 17 | Submodules populated | `git submodule status` | No line starts with `-` |
| 18 | Swipe model LFS files | `Get-ChildItem java\assets\futo-swipe` | Files are larger than 1 KB, not LFS pointer stubs |
| 19 | Layouts submodule | `Test-Path java\assets\layouts\mapping.yaml` | `True` |
| 20 | Gradle wrapper | `.\gradlew.bat --version` | Prints Gradle 8.14.3 |
| 21 | Phone connected | `adb devices` | Exactly one device listed as `device`, not `unauthorized` |
| 22 | Free disk | `Get-PSDrive C` | At least 10 GB free |
| 23 | Baseline build | `.\gradlew.bat assembleUnstableDebug` | `BUILD SUCCESSFUL` and an APK exists under `build\outputs\apk\unstable\debug\` |
| 24 | Baseline install | `adb install -r <apk>` | `Success`, and the keyboard can be enabled under Android Settings > Languages and input |

Where `$sdk` is the value of `sdk.dir` from `local.properties`.

Check 23 is the slow one. On the first run expect 20 to 60 minutes while the native whisper.cpp,
GGML, MOZC and RIME code compiles. Do not assume it hung until 60 minutes have passed with no output.

## Where the relevant code lives

Read these before proposing a change. Confirm the line numbers against the current tree, since they
come from a snapshot and upstream moves.

Key spacing:
- `java/src/org/futo/inputmethod/v2keyboard/KeyboardLayoutSet.kt`. The layout set parameters class
  holds `gap: Float = 4.0f`, in dp. This is the single source of the spacing value, and it is not
  exposed as a user setting today.
- `java/src/org/futo/inputmethod/v2keyboard/LayoutEngine.kt`. `horizontalGap = layoutParams.gap` and
  `verticalGap = layoutParams.gap * 2`. Also contains the `addGap` logic that centres short rows.
- `java/src/org/futo/inputmethod/keyboard/Key.kt`. Each key stores `horizontalGap` and `verticalGap`.
  Important: `hitBox` includes the gap, so the touch target does not shrink when the visible key
  shrinks. `drawX` offsets the drawn key by half the gap.
- `java/src/org/futo/inputmethod/keyboard/internal/KeyboardParams.java`. Holds `mHorizontalGap`,
  `mVerticalGap` and the outer padding fields. The v2 engine sets the gap fields to zero and handles
  gaps itself.
- `java/src/org/futo/inputmethod/v2keyboard/KeyboardSizingCalculator.kt`. Keyboard height, width,
  outer padding, split and one-handed sizing. These are already user settings, stored per orientation.

Layouts:
- `java/assets/layouts/` is a git submodule (Apache 2.0, github.com/futo-org/futo-keyboard-layouts).
  Each layout is a YAML file. `mapping.yaml` maps locales to layouts and `names.yaml` holds display names.
- `java/src/org/futo/inputmethod/v2keyboard/Keyboard.kt` defines the YAML schema: rows, key widths,
  `overrideWidths`, bottom row and number row modes, and per-layout `attributes`.
- `java/src/org/futo/inputmethod/v2keyboard/LayoutManager.kt` loads and parses the YAML files.
- `java/src/org/futo/inputmethod/latin/uix/settings/pages/DevLayoutEditor.kt` is a built-in editor,
  reachable from the app's developer settings, where a layout's YAML can be pasted and tested on the
  device without rebuilding. Use it for quick layout iteration before committing a YAML file.

## Experiment plan

Do these in order. Each experiment is one branch, one APK, one entry in `EXPERIMENTS.md`.

1. Baseline. Record the current gap value, keyboard height and the layout in use. Take a screenshot
   with `adb exec-out screencap -p > baseline.png`.
2. Spacing sweep. Make the gap configurable in one place, then build APKs for 2 dp, 4 dp (current),
   6 dp and 8 dp. Keep the hit box behaviour in `Key.kt` unchanged so touch targets stay contiguous.
   Later, if I find a value I like, expose it as a slider in the keyboard size settings alongside
   the existing height setting.
3. Independent horizontal and vertical spacing. Replace the fixed `gap * 2` vertical rule with a
   separate value so row spacing and column spacing can be tuned apart.
4. Layout variants. Starting from the layout my locale maps to, create copies in the layouts
   submodule that try: a wider space bar, a dedicated comma and period on the letter row, and a
   split-friendly variant. Register each in `mapping.yaml` and `names.yaml` so they appear in the
   language settings. Test each first in the developer layout editor.
5. Combine the best spacing and the best layout into one branch and build a final APK.

## Recording results

Keep `EXPERIMENTS.md` at the repository root. For each experiment record: branch name, commit hash,
what changed in one or two sentences, the APK path, and my typing observations after at least a day of
use. Leave the observation line blank for me to fill in. I will measure with the same typing test each
time, so do not change the sample text if you add one.

## When you finish a step

Report: the branch, the commit, whether the build passed, the install result, and the exact file and
line of every change. Then stop and wait for my typing feedback before starting the next experiment.
