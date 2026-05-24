## Description

Brief description of the packaging change.

## Type of Change

- [ ] New package
- [ ] Package update (new upstream version)
- [ ] Packaging fix (revision bump)
- [ ] Rebrand change (base-files / GRUB / efibootmgr / …)
- [ ] Upstream void-packages sync
- [ ] Documentation update

## Testing

- [ ] `./xbps-src lint <package>` (xlint) clean
- [ ] `./xbps-src pkg <package>` builds in a clean masterdir
- [ ] Installed / smoke-tested (in a VM for runtime-affecting changes)

## Checklist

- [ ] Uses an appropriate `build_style` (no hand-rolled steps where one fits)
- [ ] Dependencies in the right buckets (depends / makedepends / hostmakedepends)
- [ ] `version` bump updates `checksum`; packaging-only change bumps `revision`
- [ ] Rebrand stays concentrated — no mass `void` → `sunlight` rename
- [ ] Delta from upstream void-packages kept small
