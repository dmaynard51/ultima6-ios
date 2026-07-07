# Ultima VI on iOS — Changelog

Changes made to port Nuvie to iOS (iPhone/iPad). All iOS-specific code is
guarded by the `NUVIE_IOS` define, so desktop builds are unaffected.

## Engine & build system
- Cross-compiled the Nuvie engine to a native iOS app (SDL2 for iOS, CMake/Xcode
  app bundle, framework linking incl. CoreBluetooth for SDL's HID backend).
- Added physical-device code signing (`-DNUVIE_IOS_TEAM=`, automatic provisioning).
- Made the app bundle identifier configurable (`-DNUVIE_IOS_BUNDLE_ID=`, default
  `info.nuvie.ultima6`).
- Added an app icon (asset catalog wired into the CMake target); a moongate icon.
- Stubbed Lua's `os.execute`/`system()` (unavailable on iOS) to stop a startup crash.

## Game data & config
- On iOS, write `nuvie.cfg` into the app's writable `Documents` dir and `chdir`
  there — the device sandbox forbids writing the config to the container root
  (`~/.nuvierc`), which only worked on the Simulator.
- Fixed a segfault entering the world when the game data lacked `LZOBJBLK` /
  `LZDNGBLK`; the build now bundles a complete data set and fails gracefully if
  those are missing.
- Skip the intro cutscene/menu and load the most recent save straight away.

## Display
- Locked landscape orientation (plist + `SDL_HINT_ORIENTATIONS`) so the render
  and touch input stay aligned.

## Touch controls
- On-screen control overlay: a movement D-pad plus Save / Enter / Space / Esc and
  a keyboard-toggle button, each synthesising the matching Nuvie key event.
- Tap-to-walk (via SDL touch→mouse) and the game's own command bar work out of the box.
- Two-finger tap **or** the ⌨ button shows/hides the keyboard; fixed a bug that
  required two taps the first time.
- Keyboard handling: scale the game to fit above the keyboard (nothing cropped),
  and restore cleanly on hide (fixed over-zoom / bottom-crop regressions).
- Buttons live on a non-scaled passthrough overlay (constant size; empty areas
  pass touches through to the game). When the keyboard appears the overlay lifts
  and shrinks so the buttons stay reachable above it.

## Docs & housekeeping
- Getting-started guide (`ios/README.md`), controls reference (`ios/CONTROLS.md`),
  and an iOS section at the top of the main README.
- Team-ID input validation + clearer signing docs (the #1 build mistake).
- Removed a real Apple Team ID from an example in the build script.
- Donation links (Ko-fi).

---

For the full commit-by-commit history: `git log 8425eebe^..HEAD` on the
`ios-port` branch.
