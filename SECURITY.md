# Security

Keydoze intercepts input only for a user-started cleaning session. A failure that leaves input unavailable, resumes filtering unexpectedly, exposes input content, or bypasses a safety limit is security-sensitive.

## Reporting a vulnerability

Private vulnerability reporting is enabled for this repository. Use [Report a vulnerability](https://github.com/dlev02/Keydoze/security/advisories/new) to share details privately with the maintainer.

If that page is unavailable, open a public issue asking the maintainer to enable a private reporting channel, without including vulnerability details or sensitive attachments. Do not post exploit steps, private data, or input recordings in public issues.

A useful private report includes the affected commit or app version, macOS version, hardware involved, expected and observed behavior, and a minimal reproduction. Describe the recovery steps and whether any input remained unavailable. Share only information needed to investigate; do not include credentials or unrelated personal content.

## Scope and fixes

Security fixes target the current source on `main` and the latest published release, when one exists. There is no commitment to maintain older releases. Please allow time to investigate and coordinate a fix before public disclosure; this small project cannot promise a response deadline.

Use an isolated test account or device for potentially disruptive input-filtering research. Do not test against someone else's machine or data without their permission. See [AGENTS.md](AGENTS.md) for the project's safety rules and [PRIVACY.md](PRIVACY.md) for data handling.
