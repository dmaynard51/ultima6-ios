# Ultima VI on iOS (Nuvie)

This is a port of the [Nuvie](http://nuvie.sourceforge.net/) engine — an
open-source reimplementation of the *Ultima VI: The False Prophet* game engine —
to iPhone and iPad. It runs the original Ultima 6 game data as a native iOS app,
with touch controls.

It does **not** include the game itself: like Nuvie on the desktop, you supply
your own legally-owned copy of the Ultima 6 data files.

See also: [CONTROLS.md](CONTROLS.md) (touch controls) ·
[CHANGELOG.md](CHANGELOG.md) (what's changed in the port).

---

## 1. What you need

- A **Mac** with **Xcode** installed (plus command-line tools: `xcode-select --install`).
- **CMake**: `brew install cmake`
- **Your own Ultima 6 game data** (see below).
- For running on a real iPhone/iPad: a free **Apple ID** (a paid Apple Developer
  account is not required, but see the 7-day note at the bottom).

## 2. Get the Ultima 6 game data

You need the folder of original U6 data files. You can get these from any legit
copy of Ultima 6, for example:

- **GOG** — "Ultima 6: The False Prophet" (or the "Ultima 1+2+3" / Ultima
  collections that bundle it). After installing, the data lives in the game's
  install folder (on the Mac GOG/DOSBox builds, look inside the app bundle at
  `Contents/Resources/game`).
- An existing Nuvie / Exult-style install, or your original floppies/CD.

The build needs a directory containing the real U6 files, including:

```
MAP  CHUNKS  MAPTILES.VGA  OBJTILES.VGA  CONVERSE.A  CONVERSE.B
LZOBJBLK  LZDNGBLK  SCHEDULE  BASETILE  TILEFLAG  PALETTES.INT
BOOK.DAT  PORTRAIT.A  PORTRAIT.B  ...  and a SAVEGAME/ subfolder
```

> **Important:** `LZOBJBLK` and `LZDNGBLK` must be present, or starting a new
> game will fail. Some partial data dumps are missing them.

You don't copy the data anywhere by hand — you just pass the path to the build
script and it bundles the files into the app.

## 3. Build & run in the iOS Simulator (easiest — no Apple account)

```sh
ios/build-ios-sim.sh /path/to/your/ultima6-data
```

This fetches & builds SDL2 for the simulator, builds the app, and prints the
commands to install and launch it. Then:

```sh
xcrun simctl boot "iPhone 15" 2>/dev/null; open -a Simulator
xcrun simctl install booted ios/build/nuvie-build/Release-iphonesimulator/nuvie.app
xcrun simctl launch booted info.nuvie.ultima6
```

Rotate the Simulator to **landscape** (Device ▸ Rotate, or ⌘←) — Ultima 6 is a
landscape game.

## 4. Build, sign & run on a real iPhone/iPad

You need your Apple **Team ID** — a **10-character code** of letters and digits,
like `ABCDE12345`.

> ⚠️ **Pass ONLY the 10-character code.** Not your name, and **not** the whole
> `Apple Development: Your Name (ABCDE12345)` string — just the part inside the
> parentheses. Passing the full line is the #1 reason the build fails.

Where to find it (either works):

- **Apple Developer site (clearest):** [developer.apple.com/account](https://developer.apple.com/account)
  ▸ **Membership details** ▸ copy the value labelled **Team ID**.
- **Terminal:** `security find-identity -v -p codesigning` — this prints
  `"Apple Development: Your Name (ABCDE12345)"`; your Team ID is the
  `ABCDE12345` **inside the parentheses only**.
- **Xcode:** Settings ▸ Accounts ▸ add your Apple ID; the team (with its ID) is listed there.

Then run it with just that code:

```sh
ios/build-ios-device.sh ABCDE12345 /path/to/your/ultima6-data
```

(The script now checks the format and gives a clear error if you paste the wrong thing.)

The app's bundle identifier defaults to `info.nuvie.ultima6`. To use your own
(e.g. to match a specific provisioning profile), set `NUVIE_IOS_BUNDLE_ID`:

```sh
NUVIE_IOS_BUNDLE_ID=com.yourname.ultima6 \
  ios/build-ios-device.sh <YourTeamID> /path/to/your/ultima6-data
```

First-time device setup (one time each):

1. Connect the iPhone by cable, unlock it, tap **Trust This Computer**.
2. Enable **Settings ▸ Privacy & Security ▸ Developer Mode** on the phone, then
   restart it.
3. Run the build script. If Xcode has never registered this device, open
   `ios/build/nuvie-device/nuvie.xcodeproj` in Xcode once, pick the device, and
   press ▶ Run (this registers the device with your account); after that the
   script installs from the command line.
4. On the phone, trust the developer profile:
   **Settings ▸ General ▸ VPN & Device Management ▸ Developer App ▸ Trust**.

Then tap the **Ultima VI** icon and hold the phone in **landscape**.

### iPad

The app is **universal** — the exact same build, scripts, and steps above work
on iPad; the device just shows up as an iPad in `xcrun devicectl list devices`
(the device script auto-picks the first connected iPhone *or* iPad). To try it in
the **iPad Simulator**, boot an iPad instead of an iPhone:

```sh
xcrun simctl boot "iPad Pro (11-inch)" 2>/dev/null; open -a Simulator
```

Note: the on-screen controls were laid out for the iPhone's wide aspect ratio.
On the iPad's more square (4:3) screen the game is letterboxed top/bottom, so the
D-pad and action buttons still work but may not be positioned ideally — tap-to-walk,
the command bar, and the keyboard button all behave the same. (If you mainly play
on iPad, open an issue / ask and the button layout can be tuned for it.)

## 5. Playing — touch controls

See [CONTROLS.md](CONTROLS.md). In short:

- **Tap a map tile** to walk there; on-screen **D-pad** (bottom-left) also walks.
- **Command-bar icons** (top) or the letter key for actions (look, talk, get…).
- **⌨ button** (bottom-right) or a **two-finger tap** shows/hides the keyboard —
  needed for conversations (type keywords like `name`, `job`, `bye`) and naming.
- Action buttons (bottom-right): **Save** (`s`), **↵** confirm, **Spc** cancel,
  **Esc** game menu.
- **Load a specific save:** press **`s`** → pick a slot from the list → **Load**.

The app opens straight into your most recent save (the intro is skipped).

## 6. Notes / troubleshooting

- **Free Apple ID → the app expires after 7 days** and must be reinstalled (just
  re-run the device script). A paid Apple Developer account extends this to a year.
- **"No space left on device"** during install — the phone is low on storage;
  the install needs temporary staging room. Free up space and retry.
- **"errSecInternalComponent" / codesign hangs** — a keychain permission prompt;
  click **Always Allow**, or run once:
  `security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db`
- Builds are self-contained under `ios/build/` (gitignored). Delete it to start clean.

## 7. How it works

The whole app **is** Nuvie, compiled for iOS. iOS-specific code is guarded by the
`NUVIE_IOS` define so desktop builds are unaffected:

- `ios/Info.plist.in` — landscape, launch screen, touch input.
- `main.cpp` — on iOS, writes `Documents/nuvie.cfg` pointing at the bundled game
  data + a writable save dir, and uses SDL's `main` entry point.
- `ios/nuvie_ios_ui.mm` — the on-screen button overlay and keyboard handling.
- `CMakeLists.txt` — the iOS target, framework linking, data bundling, and
  optional code signing (`-DNUVIE_IOS_TEAM=`).
