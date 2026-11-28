# Contributing to slpkgs

Thank you for your interest in contributing to slpkgs, the package collection
for Sunlight Linux!

> **Status:** slpkgs is a fork of
> [void-packages](https://github.com/void-linux/void-packages), rebranded from
> Void to Sunlight Linux. The public `main` branch holds documentation and CI
> only; the `mainline-check` branch mirrors void-packages `master` (`xbps-src`,
> `Manual.md`, `srcpkgs/`); the `next` branch is `mainline-check` plus the
> Sunlight package delta, and Sunlight's packages are built from it. Template
> work goes to `next`, one commit per package change; never commit to
> `mainline-check`.

## Reporting Issues

- Use the GitHub issue tracker.
- For a build failure, include the package name, the `./xbps-src pkg <name>`
  output, your architecture, and `xbps-src` / masterdir state.

## Submitting Changes

1. Fork the repository
2. Create a feature branch from `next` (`git checkout -b pkg/my-change origin/next`)
3. Edit the template under `srcpkgs/<package>/template`
4. Lint it: `./xbps-src lint <package>` (or `xlint`)
5. Build it in a clean masterdir: `./xbps-src pkg <package>`
6. Commit and open a Pull Request

## Packaging Conventions

These follow upstream void-packages — see its `Manual.md` for the authoritative
template format.

- **Use a `build_style`** (gnu-configure, cmake, meson, go, cargo,
  python3-module, …) instead of hand-rolling `do_build`/`do_install` when one
  fits.
- **Dependency kinds are distinct:** `depends` (runtime), `makedepends` (build,
  target), `hostmakedepends` (build, host). Put each in the right place.
- **Version vs revision:** bump `version` (and update `checksum`) for a new
  upstream release; bump `revision` for a packaging-only rebuild.
- **Verify sources:** every `distfiles` entry needs a correct `checksum`.
- **Keep the upstream delta small.** Sunlight's rebrand should be concentrated
  (base-files, GRUB, efibootmgr, …) so syncing with void-packages stays easy.
  Don't mass-rename `void` → `sunlight`; package names and paths that must match
  upstream stay as they are.

## Testing

- `./xbps-src lint <package>` — template lint.
- `./xbps-src pkg <package>` — build in a chroot/masterdir.
- Install-test the result (ideally in a VM) for runtime-affecting changes.

## License

By contributing, you agree that your contributions are licensed under the
Apache License 2.0. Imported upstream void-packages templates retain their
upstream licensing.
