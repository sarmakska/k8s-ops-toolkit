# Security Policy

## Reporting a vulnerability

If you have found a security issue in this project, please report it privately. Do not open a public GitHub issue.

**Email:** security@sarmalinux.com

Please include:
- A clear description of the issue
- Steps to reproduce
- The version (commit SHA) you tested against
- Any proof-of-concept code or output

I respond to every report within 7 days. Confirmed issues are patched on `main` and released as a tagged version, and reporters are credited in the release notes unless they ask otherwise.

## Supported versions

Security fixes land on `main` and in the latest `1.x` chart release. Older
chart majors are not patched. Pin to a tagged release if you need a stable
surface, and track `main` for the current fixes.

| Version | Supported |
| --- | --- |
| chart 1.1.x (latest) | yes |
| chart 1.0.x | no, upgrade to 1.1.x |
| < 1.0 | no |

## Scope

This policy covers the code in this repository. Bugs in upstream dependencies should be reported to those projects directly.

## Out of scope

- Issues in third-party services (Vercel, Supabase, GitHub, Cloudflare, etc.)
- Findings that require physical access to a developer machine
- Theoretical risks without a working proof of concept
- Denial of service against demo / hosted instances
