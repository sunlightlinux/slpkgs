# slpkgs

The package collection for **Sunlight Linux** — a fork of
[void-packages](https://github.com/void-linux/void-packages) (the XBPS source
packages tree), rebranded from Void to Sunlight Linux.

> **Status: early bootstrap.** This repository is being seeded. It will be based
> on a void-packages fork carrying the Sunlight rebrand (base-files, GRUB,
> efibootmgr, …). Upstream's structure (`srcpkgs/`, `common/`, `xbps-src`) and
> its own documentation are merged in at import time.

## What it is

slpkgs holds the `xbps-src` templates that build the packages making up the
Sunlight Linux base system and repositories. Each package is a shell template at
`srcpkgs/<package>/template`, built in a chroot/masterdir with `xbps-src`.

## Building (xbps-src)

```bash
./xbps-src binary-bootstrap     # one-time: set up the masterdir
./xbps-src pkg <package>        # build a package
```

See void-packages' `Manual.md` for the template format and build styles.

## Rebrand

Sunlight Linux is a rebrand of Void Linux. The branding delta is intentionally
small and concentrated (base-files, bootloader/GRUB, efibootmgr, …) so syncing
with upstream void-packages stays manageable. Package names and paths that must
match upstream are left unchanged.

## Where this fits

slpkgs is one of the five projects in the Sunlight Linux tree, wired up via
[slmanifests]:

```bash
repo init -u https://github.com/sunlightlinux/slmanifests.git -b main
repo sync -j4
# slpkgs lands at pkgs/
```

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) — how to contribute (templates + xbps-src)
- [SECURITY.md](SECURITY.md) — reporting security / supply-chain issues
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — community standards
- [CLAUDE.md](CLAUDE.md) / [EXAMPLES.md](EXAMPLES.md) — guidelines for
  LLM-assisted work on package templates

## License

[Apache License 2.0](LICENSE) for Sunlight's additions and rebrand. Imported
upstream void-packages templates retain their upstream licensing.

[slmanifests]: https://github.com/sunlightlinux/slmanifests
