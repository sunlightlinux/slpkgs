# slpkgs

**The package collection for Sunlight Linux: an `xbps-src` source-package
tree, forked from void-packages and rebranded from Void.**
Each package is a shell template at `srcpkgs/<package>/template`, built in a
chroot with `xbps-src` into signed `.xbps` binary packages that
[slinstaller](https://github.com/sunlightlinux/slinstaller) installs.

| Project | Details |
|---|---|
| State | Early: the Sunlight package delta is public on `next` since 2026-11-28 (see below) |
| Public branches | `main` (docs and CI only) · `mainline-check` (exact mirror of void-packages `master`) · `next` (`mainline-check` plus the Sunlight delta; packages are built from it) |
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
> `Manual.md` (on `mainline-check` or `next`) for the template format.

## What is public today

| Branch | Content |
|---|---|
| `main` | README, CONTRIBUTING, SECURITY, CLAUDE.md, EXAMPLES.md, licence, and the CI workflows. No `srcpkgs/`, no `xbps-src`. |
| `mainline-check` | A fast-forward-only mirror of void-packages `master`: `xbps-src`, `common/`, `etc/`, `Manual.md` and about 15,000 templates, with Void's own commit hashes. Nothing Sunlight-specific is committed here. |
| `next` | `mainline-check` plus the Sunlight delta. This is the tree Sunlight's packages are built from, and the signed mirror serves those builds. |

`next` starts with one commit on top of `mainline-check`
([`21a8fc3`](https://github.com/sunlightlinux/slpkgs/commit/21a8fc38ba87061cb9328e69643749ba6e5f66a6), "Sunlight Linux: initial package delta on
void-packages"), which adds Sunlight's own packages (slinit,
slinit-services, sunlight-slinit-services, slpam, linux-next,
linux-next-full, slinstaller, sunlight-base) and changes six Void
templates (base-files, efibootmgr, grub, dracut, pam-base, sddm). Every
later package change is its own commit. Void's changes reach `next` as
merge commits, never by rebasing (see below), so a commit on `next` that
a build or the mirror refers to stays reachable.

## Building (xbps-src)

```bash
git clone -b next https://github.com/sunlightlinux/slpkgs.git
cd slpkgs
./xbps-src binary-bootstrap     # one-time: set up the masterdir
./xbps-src lint <package>       # template lint
./xbps-src pkg <package>        # build a package
```

Clone `mainline-check` instead to build Void's packages unchanged.
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

[`.github/workflows/sync-next.yml`](.github/workflows/sync-next.yml)
("Sync next") then carries the mirror into `next`. It runs after every
run of the mirror sync, whether that run succeeded or failed, and on
manual dispatch.

| Step | Behaviour |
|---|---|
| Compare | If `next` already contains `mainline-check`, do nothing |
| Merge | `git merge-tree` in a blobless bare clone, committed as "Merge void-packages master <hash> into next"; never a rebase, since builds and the mirror refer to `next`'s commits |
| Conflict | Fail and push nothing. It means Void changed a template Sunlight also changes: resolve by hand on `next`, keeping the revision above Void's |
| Credentials | The same `SLPKGS_SYNC_TOKEN`, since the merge brings in Void's edits under `.github/workflows/` |

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
