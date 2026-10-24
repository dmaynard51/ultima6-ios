#!/bin/bash
# Archive the Ultima VI DOSBox app for the App Store and upload it to TestFlight.
#
# Same patched dospad as dosbox/build-ios-dosbox.sh (that script does the clone +
# every patch; this one reuses it via U6DOS_PATCH_ONLY), but signed for
# distribution instead of development, and shipped WITHOUT game data — the build
# that goes to Apple contains no Ultima VI files at all. Testers import their own
# copy through the Files app (the app has UIFileSharingEnabled +
# UISupportsDocumentBrowser), dropping the game folder, SAVEGAME/ subdirectory
# included, into Ultima VI's Documents; it then boots straight into ULTIMA6.EXE.
#
# Prereqs (all one-time, already done for this machine):
#   - "Apple Distribution: Daniel Maynard (7M7MCVH8H9)" in the login keychain
#   - the "Ultima VI AppStore" provisioning profile installed
#   - an App Store Connect app record for the bundle id below
#   - ~/.appstoreconnect/asc.env + AuthKey_<ASC_UPLOAD_KEY>.p8 in private_keys/
#
# INTERNAL testing only. External groups need Beta App Review, and a DOS
# emulator that runs user-supplied executables is what got iDOS pulled under
# App Review guideline 2.5.2 — see the licensing note at the end of this file.
#
# Usage: dosbox/upload-testflight.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEAM="${U6DOS_TEAM:-7M7MCVH8H9}"
BUNDLE_ID="${U6DOS_BUNDLE_ID:-com.danielmaynard.ultima6}"
PROFILE="${U6DOS_PROFILE:-Ultima VI AppStore}"
ASC_UPLOAD_KEY="${ASC_UPLOAD_KEY:-TBSKA9HP23}"
WORK="${HOME}/Library/Caches/u6-dosbox"
DOSPAD="$WORK/dospad"
OUT="$WORK/testflight"

# Marketing version is this port's (1.0), not dospad's. Build number is
# year.monthday.hourminute: three small integers, so it satisfies
# CFBundleVersion's format and still rises on every run.
MARKETING="${U6DOS_VERSION:-1.0}"
BUILDNO="$(date +%Y.%m%d.%H%M)"

source ~/.appstoreconnect/asc.env
KEY="${HOME}/.appstoreconnect/private_keys/AuthKey_${ASC_UPLOAD_KEY}.p8"
[ -f "$KEY" ] || { echo "ERROR: no API key at $KEY" >&2; exit 1; }
security find-identity -v -p codesigning | grep -q "Apple Distribution: .*($TEAM)" || {
  echo "ERROR: no 'Apple Distribution' identity for team $TEAM in the keychain." >&2; exit 1; }

# 1. Clone + patch dospad exactly as the device build does (icon, one-tap autorun,
#    sound, Ultima touch keyboard, landscape lock, audio mixing). No game data is
#    staged and nothing is built or installed.
echo "Patching dospad ..."
U6DOS_PATCH_ONLY=1 U6DOS_BUNDLE_ID="$BUNDLE_ID" "$SCRIPT_DIR/build-ios-dosbox.sh" "$TEAM"

# 2. Declare export compliance up front so App Store Connect doesn't hold the
#    build for the encryption questionnaire. DOSBox uses no encryption.
plutil -replace ITSAppUsesNonExemptEncryption -bool false "$DOSPAD/Resources/iDOS-Info.plist"

# 3. Archive, signed for distribution.
echo "Archiving $BUNDLE_ID $MARKETING ($BUILDNO) ..."
rm -rf "$OUT"; mkdir -p "$OUT"
xattr -cr "$DOSPAD" 2>/dev/null || true
xcodebuild -project "$DOSPAD/dospad.xcodeproj" -scheme iDOS -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/UltimaVI.xcarchive" \
  -derivedDataPath "$DOSPAD/dd-tf" \
  DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  MARKETING_VERSION="$MARKETING" CURRENT_PROJECT_VERSION="$BUILDNO" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="$PROFILE" \
  archive | grep -E "error:|warning: .*(sign|provision)|ARCHIVE SUCCEEDED"

# 4. Export an App Store ipa.
cat > "$OUT/export.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store</string>
<key>teamID</key><string>$TEAM</string>
<key>signingStyle</key><string>manual</string>
<key>signingCertificate</key><string>Apple Distribution</string>
<key>provisioningProfiles</key><dict>
  <key>$BUNDLE_ID</key><string>$PROFILE</string>
</dict>
<key>uploadSymbols</key><true/>
</dict></plist>
PL
xcodebuild -exportArchive -archivePath "$OUT/UltimaVI.xcarchive" \
  -exportOptionsPlist "$OUT/export.plist" -exportPath "$OUT/export" \
  | grep -E "error:|EXPORT SUCCEEDED"
IPA="$(find "$OUT/export" -name '*.ipa' | head -1)"
[ -n "$IPA" ] || { echo "ERROR: no ipa produced" >&2; exit 1; }
echo "ipa: $IPA ($(du -h "$IPA" | cut -f1))"

# 5. Confirm the ipa really is data-free before it leaves the machine.
if unzip -l "$IPA" | grep -qiE "ULTIMA6\.EXE|LZOBJBLK|SAVEGAME/"; then
  echo "ERROR: the ipa contains Ultima VI game data — refusing to upload." >&2
  exit 1
fi
echo "Verified: no Ultima VI data in the ipa."

# 6. Upload to TestFlight.
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_UPLOAD_KEY" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | tail -5
echo
echo "Uploaded build $BUILDNO. It shows up in TestFlight after Apple finishes"
echo "processing (usually 5-15 min). Internal testers get it with no review."

# Licensing note: dospad is GPLv2 and Daniel is not its copyright holder, so
# distributing this build beyond internal testing is the classic GPL/App Store
# conflict (Apple's terms add restrictions GPL section 6 forbids). litchie can
# ship iDOS on the store because he owns the code; this port can't. Keep it to
# internal TestFlight, or go back to the unsigned sideload ipa in the GitHub
# release for anyone else.
