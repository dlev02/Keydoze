# Releasing Keydoze

## Current distribution status

On 21 October 2026, version 0.1.0 build 3 was signed with **Developer ID Application: Brandon Stellina (7BVMD7TA97)**, hardened runtime, and a secure timestamp, then accepted by Apple notarization (submission `00f9d568-15b8-4d7a-bd2e-89b8443a1925`). The ticket was stapled and validated, and Gatekeeper reports `source=Notarized Developer ID`. The notarized app is published in the `v0.1.0` GitHub release as a DMG with a drag-to-Applications window (SHA-256 `e9a53f3a9174363823e9494d178624a4083c54d122fbdabf098f8ee4597127bf`, notarization submission `679c1732-cae7-4837-a395-7ebc9cd72062`) and as a ZIP (SHA-256 `56ca0ca17a17605724b0de926351a42b23c225abd594b1248e55dc46e59321e3`).

Earlier submissions under the previous team (`M379WPVT8A`, whose Developer ID certificate was revoked) are superseded. Notarization uses an App Store Connect team API key stored in the system keychain through `asc auth login`; no credentials are stored in this repository. To check a submission:

```sh
asc notarization status --id 00f9d568-15b8-4d7a-bd2e-89b8443a1925 --output json
```

After Apple reports **Accepted**, staple and validate the ticket, verify Gatekeeper acceptance, and package that stapled app for the public release. If Apple rejects it, inspect `asc notarization log --id SUBMISSION_ID` and resolve the reported issue first.

## Distribution workflow

The default local optimized app/archive is **Apple silicon only** and uses hardened runtime and development signing. It is not notarized by the build script. Sign a separate distribution copy, preserving the stable development app's permission identity:

```sh
./script/build_and_run.sh --release
mkdir -p dist/distribution
ditto 'dist/Keydoze.app' 'dist/distribution/Keydoze.app'
codesign --force --options runtime --timestamp --sign 'Developer ID Application: YOUR NAME (TEAMID)' 'dist/distribution/Keydoze.app'
codesign --verify --strict 'dist/distribution/Keydoze.app'
ditto -c -k --keepParent 'dist/distribution/Keydoze.app' dist/Keydoze-submission.zip
asc notarization submit --file dist/Keydoze-submission.zip --wait --output json
# Continue only when the submission status is Accepted.
xcrun stapler staple 'dist/distribution/Keydoze.app'
xcrun stapler validate 'dist/distribution/Keydoze.app'
spctl --assess --type execute --verbose 'dist/distribution/Keydoze.app'
ditto -c -k --keepParent 'dist/distribution/Keydoze.app' dist/Keydoze.zip
```

For a drag-to-Applications installer, stage the stapled app beside a symlink to `/Applications`, create a read-write image with `hdiutil create -srcfolder`, arrange the icons in Finder (icon view, app left, Applications right), convert it with `hdiutil convert -format UDZO`, then `codesign --timestamp`, `asc notarization submit --wait`, and `xcrun stapler staple` the DMG itself.

## Source publication checklist

- Review the latest source, README screenshots, LICENSE, NOTICE, privacy policy, and community documents.
- Confirm the public repository target is `dlev02/Keydoze` and publication is approved.
- Push the reviewed commit and verify the remote SHA. Watch the CI result before claiming it passed.
- Verify GitHub private vulnerability reporting remains enabled and SECURITY.md matches the available reporting channel.
- Source publication and a notarized binary release are separate milestones. Do not attach the local development-signed archive as a notarized download.

The workflow above does not itself establish that a release has been published. Overall laptop hardware behavior has been confirmed by the developer; remaining device and isolated failure coverage is recorded in [VALIDATION.md](VALIDATION.md). Do not disable Gatekeeper or other system protections to work around signing failures.
