# Releasing Keydoze

The local optimized app/archive is **Apple silicon only** and uses hardened runtime and development signing. **It is not Developer ID signed or notarized.** A downloadable macOS binary release requires a Developer ID Application certificate and notarization. Sign a separate distribution copy, preserving the stable development app's permission identity:

```sh
./script/build_and_run.sh --release
mkdir -p dist/distribution
ditto 'dist/Keydoze.app' 'dist/distribution/Keydoze.app'
codesign --force --options runtime --timestamp --sign 'Developer ID Application: YOUR NAME (TEAMID)' 'dist/distribution/Keydoze.app'
codesign --verify --strict 'dist/distribution/Keydoze.app'
ditto -c -k --keepParent 'dist/distribution/Keydoze.app' dist/Keydoze-submission.zip
xcrun notarytool submit dist/Keydoze-submission.zip --keychain-profile YOUR_PROFILE --wait
xcrun stapler staple 'dist/distribution/Keydoze.app'
xcrun stapler validate 'dist/distribution/Keydoze.app'
spctl --assess --type execute --verbose 'dist/distribution/Keydoze.app'
ditto -c -k --keepParent 'dist/distribution/Keydoze.app' dist/Keydoze.zip
```

## Source publication checklist

- Review the latest source, README screenshots, LICENSE, NOTICE, privacy policy, and community documents.
- Confirm the public repository target is `dlev02/Keydoze` and publication is approved.
- Push the reviewed commit and verify the remote SHA. Watch the CI result before claiming it passed.
- Verify GitHub private vulnerability reporting remains enabled and SECURITY.md matches the available reporting channel.
- Source publication and a notarized binary release are separate milestones. Do not attach the local development-signed archive as a notarized download.

The signing commands above are future release instructions, not completed publication steps. Validate physical input and isolated failure cases first. Do not disable Gatekeeper or other system protections to work around signing failures.
