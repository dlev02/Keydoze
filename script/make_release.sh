#!/bin/zsh
# Builds a Keydoze release in dist/release/<version>: a Developer ID signed, notarized and stapled
# DMG and ZIP, a signed Sparkle appcast.xml pointing at the release's tag, and SHA-256 checksums.
# It uploads nothing. See docs/RELEASING.md.
#
#   script/make_release.sh 0.2.0
#
# Set the version and a higher build number in Resources/Info.plist first and commit. Needs, on this Mac:
#   - The Developer ID Application certificate for team 7BVMD7TA97, in the login Keychain.
#   - The notarization key that `asc auth login` stores in the keychain.
#   - The Sparkle private key, in the login Keychain under the account `keydoze`. macOS may ask once
#     to let generate_appcast read it. Lose this key and every installed copy needs a download by hand.
set -euo pipefail

cd "${0:A:h:h}"

die() { print -u2 "make_release: $*"; exit 1; }
step() { print "\n== $*"; }

version="${1:-}"
[[ "$version" =~ '^[0-9]+(\.[0-9]+)+$' ]] || die "usage: make_release.sh <version>, for example 0.2.0"

team=7BVMD7TA97
account=keydoze
tag="v$version"
repo=https://github.com/dlev02/Keydoze
feed="$repo/releases/latest/download/appcast.xml"
out="dist/release/$version"
sparkle_bin=.build/artifacts/sparkle/Sparkle/bin
plist=Resources/Info.plist
dmg="Keydoze-$version.dmg"
zip="Keydoze-$version.zip"

# Everything that needs setting up on this Mac fails here, not after a long build.
git diff --quiet HEAD -- || die "tracked files have changes: commit first, so the release is what's in the repository"
[[ "$(plutil -extract CFBundleShortVersionString raw "$plist")" == "$version" ]] || die "$plist doesn't say $version"
build=$(plutil -extract CFBundleVersion raw "$plist")
[[ "$build" =~ '^[0-9]+$' ]] || die "the build number must be a whole number, not $build"
print -r -- "$(sed -n "/^## $version /,/^## /p" CHANGELOG.md | sed '1d;$d')" | grep -q '[^[:space:]]' || die "CHANGELOG.md has no section for $version"

identity=$(security find-identity -v -p codesigning | awk -v team="($team)" '/Developer ID Application/ && index($0, team) { print $2; exit }')
[[ -n "$identity" ]] || die "no Developer ID Application certificate for team $team in the Keychain"

swift package --disable-sandbox resolve
public_key=$("$sparkle_bin/generate_keys" --account "$account" -p) || die "no Sparkle key for account $account in the Keychain"
[[ "$public_key" == "$(plutil -extract SUPublicEDKey raw "$plist")" ]] || die "the Keychain's Sparkle key doesn't match SUPublicEDKey"
[[ "$(plutil -extract SUFeedURL raw "$plist")" == "$feed" ]] || die "SUFeedURL isn't $feed"

# Sparkle compares CFBundleVersion, so a build number that doesn't rise never reaches anyone.
published=$(curl -fsL "$feed" | sed -n 's|.*<sparkle:version>\([0-9]*\)</sparkle:version>.*|\1|p' | sort -n | tail -1 || true)
if [[ -n "$published" ]] && (( build <= published )); then
  die "build $build isn't higher than the published build $published"
fi

rm -rf "$out"
mkdir -p "$out"
app="$out/Keydoze.app"

step "Building"
./script/build_and_run.sh --release >"$out/build.log" 2>&1 || { tail -30 "$out/build.log"; die "the build failed; see $out/build.log"; }
ditto dist/Keydoze.app "$app"

step "Signing with Developer ID"
script/sign_app.sh "$app" --force --options runtime --timestamp --sign "$identity"
codesign --verify --deep --strict "$app" || die "the app's signature doesn't verify"
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
for code in "$app" "$sparkle" "$sparkle/Autoupdate" "$sparkle/Updater.app"; do
  details=$(codesign -dvv "$code" 2>&1)
  [[ "$details" == *"Authority=Developer ID Application"* && "$details" == *"TeamIdentifier=$team"* ]] || die "$code isn't signed with team $team's Developer ID"
  [[ "$details" == *"(runtime)"* ]] || die "$code has no hardened runtime"
  [[ "$details" == *"Timestamp="* ]] || die "$code has no secure timestamp"
done
if strings "$app/Contents/MacOS/Keydoze" | grep -q '/Users/'; then die "the executable contains a local path"; fi

notarize() {
  local result="$out/notary-${1:t}.json"
  asc notarization submit --file "$1" --wait --output json >"$result" || true
  local verdict; verdict=$(plutil -extract data.attributes.status raw "$result" 2>/dev/null || print unknown)
  if [[ "$verdict" != "Accepted" ]]; then
    local id; id=$(plutil -extract data.id raw "$result" 2>/dev/null || print "")
    [[ -n "$id" ]] && asc notarization log --id "$id" || true
    die "notarizing ${1:t} came back $verdict"
  fi
}

step "Notarizing the app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/submission.zip"
notarize "$out/submission.zip"
rm "$out/submission.zip"
xcrun stapler staple -q "$app"
xcrun stapler validate -q "$app"
spctl --assess --type execute "$app" || die "Gatekeeper refuses the stapled app"

step "Making the ZIP"
# ditto keeps the framework's symlinks, which a plain zip would break.
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/$zip"

step "Making and notarizing the DMG"
# dmg-layout.DS_Store holds the Finder window for the drag to Applications: app left, Applications right.
folder="$out/dmg"
mkdir "$folder"
ditto "$app" "$folder/Keydoze.app"
ln -s /Applications "$folder/Applications"
cp Resources/DMG/dmg-layout.DS_Store "$folder/.DS_Store"
hdiutil create -quiet -volname Keydoze -srcfolder "$folder" -ov -format UDZO "$out/$dmg"
rm -rf "$folder"
codesign --sign "$identity" --timestamp "$out/$dmg"
notarize "$out/$dmg"
xcrun stapler staple -q "$out/$dmg"
xcrun stapler validate -q "$out/$dmg"
spctl --assess --type open --context context:primary-signature "$out/$dmg" || die "Gatekeeper refuses the DMG"

step "Signing the appcast"
# Only the ZIP goes in: Sparkle installs from it, and the DMG is for people. The changelog section
# becomes the release notes in the update window. The appcast must always be attached to the latest
# release: installed copies read it from there.
stage="$out/appcast-stage"
mkdir "$stage"
ln "$out/$zip" "$stage/$zip"
print -r -- "$(sed -n "/^## $version /,/^## /p" CHANGELOG.md | sed '1d;$d')" >"$stage/${zip:r}.md"
"$sparkle_bin/generate_appcast" --account "$account" --embed-release-notes --maximum-deltas 0 \
  --download-url-prefix "$repo/releases/download/$tag/" --link "$repo/releases/tag/$tag" \
  -o "$PWD/$out/appcast.xml" "$stage" | tee "$out/appcast.log"
rm -rf "$stage"
xmllint --noout "$out/appcast.xml"
grep -q "url=\"$repo/releases/download/$tag/$zip\"" "$out/appcast.xml" || die "the appcast's enclosure doesn't point at $tag"
grep -q "<sparkle:version>$build</sparkle:version>" "$out/appcast.xml" || die "the appcast doesn't offer build $build"
grep -q 'sparkle:edSignature=' "$out/appcast.xml" || die "the download isn't signed in the appcast"
grep -q 'sparkle-signatures:' "$out/appcast.xml" || die "the appcast itself isn't signed, and the app requires that"

step "Checksums"
(cd "$out" && shasum -a 256 "$dmg" >"$dmg.sha256" && shasum -a 256 "$zip" >"$zip.sha256" && shasum -a 256 appcast.xml >appcast.xml.sha256 && cat ./*.sha256)

print "\nReady in $out. Nothing has been uploaded. To publish, attach these to the release tagged $tag:"
print "  $dmg  $dmg.sha256  $zip  $zip.sha256  appcast.xml  appcast.xml.sha256"
print "Installed copies see it once that release is the latest: a draft or prerelease is invisible to them."
