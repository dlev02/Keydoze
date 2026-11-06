# Releasing Keydoze

## Current distribution status

On 5 November 2026, version 0.2.0 build 4 was published as the `v0.2.0` GitHub release from commit `bdea69d`. It is signed with **Developer ID Application: Brandon Stellina (7BVMD7TA97)**, hardened runtime, and secure timestamps, including Sparkle's helpers. Apple accepted the app (submission `2b4a9fbe-64a7-41ae-8d33-2aaf835e95c2`) and the DMG (submission `cc82d4a3-333e-497c-aa60-9afcdc642b87`). Both tickets are stapled, and Gatekeeper reports `source=Notarized Developer ID`. Checksums are attached to the release: DMG SHA-256 `d7d0deae9a1afb359d2903ffcb72798bbb0e2fa31a6e5c5100949d2e9ba42888`, ZIP SHA-256 `a6f03b52a5b7a659001568cf3a8496dcdddc3cba9e41eaf959bca2f33c99bbb4`.

Earlier submissions under the previous team (`M379WPVT8A`, whose Developer ID certificate was revoked) are superseded. Notarization uses an App Store Connect team API key stored in the system keychain through `asc auth login`; no credentials are stored in this repository. To check a submission:

```sh
asc notarization status --id 2b4a9fbe-64a7-41ae-8d33-2aaf835e95c2 --output json
```

After Apple reports **Accepted**, staple and validate the ticket, verify Gatekeeper acceptance, and package that stapled app for the public release. If Apple rejects it, inspect `asc notarization log --id SUBMISSION_ID` and resolve the reported issue first.

## Distribution workflow

1. Set `CFBundleShortVersionString` and a higher `CFBundleVersion` in `Resources/Info.plist`. Sparkle compares `CFBundleVersion`, so a build number that doesn't rise never reaches anyone.
2. Add the version's section to `CHANGELOG.md`, in the form `## 0.2.0 — date`. Its text becomes the release notes in the update window, so write it for people.
3. Update the README's download name and merge. Build from the merged `main`, with no local changes.
4. Run `script/make_release.sh <version>`. It checks this Mac first (Developer ID certificate, Sparkle key, version, build number against the published feed), then builds the Developer ID copy from the inside out with hardened runtime and secure timestamps, notarizes and staples the app, makes the ZIP, makes, signs, notarizes and staples the DMG, signs the appcast, and writes checksums to `dist/release/<version>`. It uploads nothing.
5. Create the release as a draft, attach the DMG, ZIP, `appcast.xml` and their `.sha256` files, then publish it as the latest. A draft or prerelease is invisible to installed copies.
6. Download the published `appcast.xml` and DMG and check them against the checksums. Then update the website if the download or privacy copy changed.

Don't publish a later release without `appcast.xml`: installed copies read it from the latest release, and a 404 stops them finding updates. Only the ZIP goes in the appcast. The DMG is for first installs, and its drag-to-Applications window comes from `Resources/DMG/dmg-layout.DS_Store`.

## Update signing key

Updates are signed with an EdDSA key made by Sparkle's `generate_keys --account keydoze`. The private half is only in the login Keychain and is read by `generate_appcast`; macOS may ask once to allow that. The public half is `SUPublicEDKey` in `Resources/Info.plist`. Don't use Sparkle's default account: that key is another project's.

Back it up once, somewhere safe outside this repository, with `generate_keys --account keydoze -x <file>`, and delete the exported file after storing it. Lose this key and every installed copy needs a download by hand, because `SUSignedFeedFailureExpirationInterval` is 0: nothing falls back to accepting an unsigned feed. Restore with `generate_keys --account keydoze -f <file>`.

## Source publication checklist

- Review the latest source, README screenshots, LICENSE, NOTICE, privacy policy, and community documents.
- Confirm the public repository target is `dlev02/Keydoze` and publication is approved.
- Push the reviewed commit and verify the remote SHA. Watch the CI result before claiming it passed.
- Verify GitHub private vulnerability reporting remains enabled and SECURITY.md matches the available reporting channel.
- Source publication and a notarized binary release are separate milestones. Do not attach the local development-signed archive as a notarized download.

The workflow above does not itself establish that a release has been published. Overall laptop hardware behavior has been confirmed by the developer; remaining device and isolated failure coverage is recorded in [VALIDATION.md](VALIDATION.md). Do not disable Gatekeeper or other system protections to work around signing failures.
