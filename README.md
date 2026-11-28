# slpkgs

**The package collection for Sunlight Linux: an `xbps-src` source-package
tree, forked from void-packages and rebranded from Void.**
Each package is a shell template at `srcpkgs/<package>/template`, built in a
chroot with `xbps-src` into signed `.xbps` binary packages that
[slinstaller](https://github.com/sunlightlinux/slinstaller) installs.

| Project | Details |
|---|---|
| State | Early: the Sunlight package delta is not yet on a public branch (see below) |
| Public branches | `main` (docs and CI only) · `mainline-check` (exact mirror of void-packages `master`) |
| Upstream | [void-linux/void-packages](https://github.com/void-linux/void-packages) |
| Requires | A Linux host able to run `xbps-src` (see upstream `Manual.md`) |
| License | Apache 2.0 for Sunlight's additions; imported void-packages templates keep their upstream licensing |

Sunlight Linux is a Void-based distribution that runs
[slinit](https://github.com/sunlightlinux/slinit) as PID 1. slpkgs is where
its packages are defined: Void's templates, plus a small Sunlight delta
(rebranded base packages such as base-files, GRUB and efibootmgr; and
Sunlight's own packages such as the init system and the kernel).

**Deliberately out of scope:** a wide rename of `void` to `sunlight`
(package names, paths and mirrors that must match upstream stay as they
are), vendored sources (templates use `distfiles` plus `checksum`), and a
replacement for `xbps-src` or its packaging manual.

> **New here?** Read [CLAUDE.md](CLAUDE.md) for the rules this repository
> keeps (small mergeable delta, verified sources), then upstream's
> `Manual.md` on the `mainline-check` branch for the template format.

## What is public today

| Branch | Content |
|---|---|
| `main` | README, CONTRIBUTING, SECURITY, CLAUDE.md, EXAMPLES.md, licence, and the CI workflow. No `srcpkgs/`, no `xbps-src`. |
| `mainline-check` | A fast-forward-only mirror of void-packages `master`: `xbps-src`, `common/`, `etc/`, `Manual.md` and about 15,000 templates, with Void's own commit hashes. Nothing Sunlight-specific is committed here. |

The Sunlight delta (the rebranded base packages and Sunlight's own
templates, for example sunlight-base, slinit, slpam and the kernel packages)
is not on a public branch yet. `mainline-check` is the base it will be built
on top of. Until then, the build instructions below work against
`mainline-check` and produce Void's packages, not Sunlight's.

## Building (xbps-src)

```bash
git clone -b mainline-check https://github.com/sunlightlinux/slpkgs.git
cd slpkgs
./xbps-src binary-bootstrap     # one-time: set up the masterdir
./xbps-src lint <package>       # template lint
./xbps-src pkg <package>        # build a package
```

Sunlight's binary packages are served from a signed package mirror.
[slinstaller](https://github.com/sunlightlinux/slinstaller/blob/v2.3.1/cmd/slinstaller/main.go)
layers it ahead of Void's repository on installed systems
(`defaultExtraRepo`, overridable with `--extra-repo`).

## How the mirror works

[`.github/workflows/sync-mainline-check.yml`](.github/workflows/sync-mainline-check.yml)
runs twice a day (03:30 and 15:30 UTC) and on manual dispatch.

| Step | Behaviour |
|---|---|
| Clone | Bare, single-branch clone of void-packages `master` |
| Compare | If `mainline-check` already equals upstream, do nothing |
| Guard | If `mainline-check` holds a commit upstream lacks, fail rather than merge: nothing is meant to be committed there |
| Push | Fast-forward only. A large gap is pushed in steps of 20,000 first-parent commits over HTTP/1.1; a day's update is one small push |
| Credentials | The `SLPKGS_SYNC_TOKEN` secret (fine-grained, this repository only, Contents and Workflows read/write), because upstream edits `.github/workflows/` and `GITHUB_TOKEN` cannot push such commits. Upstream's own workflows do not run here |

## Rebrand policy

The branding delta is kept small and concentrated (base-files, bootloader
packages, efibootmgr, and similar), so that syncing with void-packages stays
routine. Package names and paths that must match upstream are left
unchanged. Prefer changes that upstream could accept.

## Documentation

| Document | Contents |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute: template workflow and packaging conventions |
| [SECURITY.md](SECURITY.md) | Supply-chain scope and how to report a vulnerability |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | Community standards |
| [CLAUDE.md](CLAUDE.md) | Guidelines for LLM-assisted work on templates |
| [EXAMPLES.md](EXAMPLES.md) | Worked `xbps-src` scenarios for those guidelines |
| `Manual.md` (on `mainline-check`) | Upstream's authoritative packaging manual |

## Testing

| Check | Command |
|---|---|
| Template lint | `./xbps-src lint <package>` |
| Build in a clean masterdir | `./xbps-src pkg <package>` |
| Runtime | Install the built `.xbps`, ideally in a VM |

## Where this fits

slpkgs is one of the projects in the Sunlight Linux tree, wired up by
[slmanifests](https://github.com/sunlightlinux/slmanifests):

```bash
repo init -u https://github.com/sunlightlinux/slmanifests.git -b main
repo sync -j4
# slpkgs lands at pkgs/
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Commit messages are `area: short
summary` plus a paragraph on why.

## License

[Apache License 2.0](LICENSE) for Sunlight's additions and rebrand. Imported
upstream void-packages templates retain their upstream licensing.
