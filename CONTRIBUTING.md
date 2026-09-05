# Contributing to Keydoze

Bug reports, focused fixes, documentation improvements, and careful accessibility testing are welcome. For a substantial feature or a change to input filtering or recovery, open an issue describing the problem and proposed behavior before starting a large implementation.

## Development

Use macOS 26 or later and Xcode 26 or later with Swift 6.2 or newer. The project has no package dependencies. Read [AGENTS.md](AGENTS.md) for its safety invariants and local commands.

```sh
swift test --disable-sandbox
swift build --disable-sandbox -c release
./script/build_and_run.sh --simulate
```

The test suite exercises the deterministic session state and in-memory macOS event conversion. It never installs input taps or posts events. Simulation previews also never install a tap. Run macOS adapter tests in a logged-in graphical session so CoreGraphics can initialize its connection to the window server.

Live filtering checks are separate from automated tests. Use a short session and arm an independent process-kill watchdog before activation. Test permission revocation, sleep, and user switching on an isolated account or device, not a primary Mac. Do not claim that system gestures, hardware keys, or security paths are blocked without specific evidence.

## Pull requests

Keep a change focused and preserve unrelated work. Describe the user-visible result, relevant checks, and anything you could not verify. Add regression coverage for meaningful behavior changes; content and link checks are usually enough for documentation. Do not include signing keys, credentials, local diagnostics, personal paths, or generated app bundles.

Keydoze must remain offline and must never store typed content, replay suppressed input, automatically restart an interrupted session, or leave an event tap installed while idle. Changes to those boundaries need explicit discussion.

## License and attribution

Contributions intentionally submitted for inclusion in Keydoze are under the [Apache License 2.0](LICENSE), unless explicitly stated otherwise. Submit only work you have the right to contribute and identify any third-party material and its license.

When redistributing this project or a derivative, follow section 4 of the license: provide a copy of the license, retain the relevant copyright, patent, trademark, and attribution notices, and place prominent notices in modified files stating that you changed them. Preserve the applicable attribution in [NOTICE](NOTICE) in one of the forms allowed by the license, such as a distributed NOTICE file or documentation. These are distribution obligations; Apache 2.0 does not require publishing derivative source code or displaying a credit in every app screen. It does not grant trademark rights beyond the uses described in the license.
