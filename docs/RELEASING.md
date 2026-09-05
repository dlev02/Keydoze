# Releasing Keydoze

## Current distribution status

On 6 September 2026, the separate distribution copy was signed with **Developer ID Application: Benjamin Levinson (M379WPVT8A)**, hardened runtime, and a secure timestamp. Strict signature verification passed. The compact About window is included in version 0.1.0 build 2. Apple received submission `1b3d5b85-951a-4049-98cf-ab8d2cf72ff4`; its latest observed status is **In Progress**. A notarized binary download has not yet been published.

The earlier build 1 submission is superseded; release only build 2 from `dist/distribution-build2/Keydoze.app`.

The existing `asc` Keychain authentication worked; no credentials are stored in this repository. Check this submission before uploading another:

```sh
asc notarization status --id 1b3d5b85-951a-4049-98cf-ab8d2cf72ff4 --output json
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

## Source publication checklist

- Review the latest source, README screenshots, LICENSE, NOTICE, privacy policy, and community documents.
- Confirm the public repository target is `dlev02/Keydoze` and publication is approved.
- Push the reviewed commit and verify the remote SHA. Watch the CI result before claiming it passed.
- Verify GitHub private vulnerability reporting remains enabled and SECURITY.md matches the available reporting channel.
- Source publication and a notarized binary release are separate milestones. Do not attach the local development-signed archive as a notarized download.

The workflow above does not itself establish that a release has been published. Overall laptop hardware behavior has been confirmed by the developer; remaining device and isolated failure coverage is recorded in [VALIDATION.md](VALIDATION.md). Do not disable Gatekeeper or other system protections to work around signing failures.
