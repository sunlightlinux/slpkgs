# Security Policy

## Scope

slpkgs is the package collection for Sunlight Linux — a fork of
[void-packages](https://github.com/void-linux/void-packages). It is
**supply-chain sensitive**: these `xbps-src` templates decide what source is
downloaded, how it is built, and what lands in users' systems.

Security-relevant areas:

- **Distfile integrity** — every `distfiles` source must have a correct
  `checksum`; build must fail on mismatch.
- **Template trust** — templates run shell during build; a malicious or
  compromised template runs arbitrary code on builders.
- **Rebrand patches** — Sunlight's changes to packages (base-files, GRUB,
  efibootmgr, …) must not weaken upstream security defaults.
- **Mirror / fetch** — sources fetched over trusted, HTTPS mirrors.
- **Package signing** — built repositories are signed; keys are protected.

## Reporting a Vulnerability

If you discover a security issue in a Sunlight package, template, or rebrand
patch, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please send an email to: ionut_n2001@yahoo.com

Include:
- Affected package / template
- Description of the issue
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You should receive a response within 48 hours. We will coordinate a fix before
any public disclosure.

> For vulnerabilities in **upstream void-packages** (not Sunlight's rebrand or
> additions), report them to the Void Linux security process. For issues in the
> **upstream software** a package builds, report to that project.
