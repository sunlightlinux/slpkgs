# slinit services in Sunlight packages

Sunlight runs [slinit](https://github.com/sunlightlinux/slinit) as PID 1.
Every package that ships a daemon ships its slinit service too, next to the
runit one, so that

    xbps-install docker
    slinitctl enable docker

is all it takes. This file is the rule book for writing those services. It
is read by people and by the AI agents that do most of the conversion, and
it is meant to be followed literally.

Runit support will be removed from Sunlight later; until then a package
carries both, and the two must describe the same daemon the same way.

## Where things go

| What | Source in the template dir | Installed as |
|---|---|---|
| The service | `files/<service>.slinit` | `/usr/lib/slinit.d/<service>` |
| A helper script it runs, if any | `files/<service>.slinit-run` | `/usr/libexec/slinit/<service>` (755) |
| Its stop, finish and readiness-check helpers, if any | `files/<service>.slinit-stop`, `.slinit-finish`, `.slinit-check` | `/usr/libexec/slinit/<service>-stop`, `-finish`, `-check` (755) |
| Default configuration, if the runit service had a `conf` | `files/<service>.slinit-conf` | `/etc/conf.d/<service>` (644) |

`vslinit <service>` installs every one of these that exists (see
`Manual.md` at the top of the tree); the template still lists
`/etc/conf.d/<service>` in `conf_files` when there is a `.slinit-conf`,
and needs no `vinstall` line for any of them. Put the
`vslinit` line directly after the `vsv` line of the same service, in the
same function (also when `vsv` sits in a subpackage's `pkg_install`; no
`vmove` is needed then), and bump `revision`. A subpackage that `vmove`s
`etc/sv/<service>` also moves everything vslinit installed for it:
`usr/lib/slinit.d/<service>`, `usr/libexec/slinit/<service>` (and its
`-stop`, `-finish`, `-check`), `etc/conf.d/<service>`, and, with
`enable`, `usr/lib/slinit.d/boot.d/<service>`. Move them before another
subpackage moves a whole directory (`vmove usr/libexec` in a -common
package would otherwise take the helper away from its service).

`<service>` is the name `vsv` uses, so a daemon is enabled by the same name
under either init. Never invent another one. A second `vsv` argument
(`vsv cronie cron`) is a syslog facility for runit's logger and plays no
part in the slinit service.

## The rules

1. **Not enabled by default.** Use `vslinit <service>`, not `vslinit
   <service> enable`. The default set is the maintainer's decision; it is
   listed in `srcpkgs/slinit-services/files/services/system`'s comment and
   is not changed by a conversion.

2. **One daemon in the foreground: `type = process`.** The runit `run`
   script already starts the daemon in the foreground; keep its foreground
   flags (`-n`, `-f`, `-D`, `--nofork`, ...). A one-shot job is
   `type = scripted`.

3. **`command` is an absolute path, with no shell.** Find the path from the
   template's install steps (`vbin` means `/usr/bin`) or the built package,
   not from `$PATH`: a service gets no login `PATH`. `command` expands
   `$VAR` from the service environment, so a literal `$` is written `$$`,
   and a backslash is eaten, so avoid both.

4. **Anything a shell does goes in a helper**, `files/<service>.slinit-run`:
   POSIX `sh`, `set -u` (and `-e` too if the run script had it), absolute
   paths (in a `sh -c` string too), ending in
   `exec /absolute/daemon ...`; the service's `command` is then
   `/usr/libexec/slinit/<service>`. That covers sourcing a configuration
   file, more than one preparation step, `modprobe`, `ulimit` beyond
   `rlimit-nofile`, and conditionals. One preparation step alone may be a
   `pre-start-command` instead (rule 7).

5. **Configuration is `/etc/conf.d/<service>`**, never `/etc/sv/...`, which
   goes away with runit. If the runit `run` does `[ -r conf ] && . ./conf`,
   the helper does

       [ -r /etc/conf.d/<service> ] && . /etc/conf.d/<service>

   and uses the same variables (`$OPTS`, ...). If Void ships a default
   `files/<service>/conf`, copy it to `files/<service>.slinit-conf` and add
   `/etc/conf.d/<service>` to `conf_files`; `vslinit` installs it. A
   run script that uses `${OPTS:=default}` but sources no conf has the
   default written straight into `command`; one that sources a conf and
   uses `${OPTS:=default}` or `${OPTS:-default}` keeps that expansion in
   the helper, after `OPTS=` and the `.` line; with `${OPTS=default}`
   (no colon) leave out the `OPTS=` line, or the default never applies.
   With `run-as`, the helper itself runs as that user, so it reads the
   conf as that user, where runit read it as root before `chpst`. A conf
   the package's documentation says may hold a secret must then be
   readable by that user; say so in that documentation. A package document that tells
   users to edit `/etc/sv/<service>/conf` (a `README.voidlinux`, say) is
   changed to `/etc/conf.d/<service>` in the same commit. A run script
   that sources the package's own configuration elsewhere
   (`/etc/kubernetes/config`) keeps that path. Every variable a helper uses
   is set (`VAR=`) before the `.` line, as `set -u` fails on an unset one,
   except a variable the helper only `export`s for a daemon that tells
   unset from empty (nodm): leave that one unset. A run script that sources
   `/etc/profile` does so in the helper before `set -u`.
   Do not use `env-file`: it reads
   `KEY=value` literally, and Void's files are shell (`OPTS="-x"` would
   keep the quotes).

6. **Output goes to the journal: `log-type = journal`** on every
   `type = process` service. Drop runit's `exec 2>&1` and the `log/`
   service; `slinit-journalctl -u <service>` replaces `vlogger`. Two
   exceptions keep what the run script asked for:
   - a run script that discards all output on the daemon's exec line
     (`>/dev/null 2>&1`) gets `log-type = none`, with a comment saying so;
   - a `2>&1` on the daemon's own exec line is dropped: the journal takes
     both streams;
   - a redirection of one stream only stays on the `exec` line of a
     helper, since `command` has no shell: `2>&1 >/dev/null`, and also
     `exec 2>&1` followed by `exec daemon >/dev/null`, which keeps stderr.

7. **Preparing a directory:** `install -d -m 0755 -o u -g g /run/x` becomes

       pre-start-command = +/usr/bin/install -d -m 0755 -o u -g g /run/x

   The `+` runs it as root even with `run-as` (and is left off without
   `run-as`). `mkdir -p X` plus `chown u:g X` is the same single
   `install -d -o u -g g X`, and a lone `mkdir -p X` (or `[ -d X ] ||
   mkdir -p X`) is `pre-start-command = /usr/bin/mkdir -p X`; under
   `run-as`, where the helper cannot chown, this is the only place for
   them.

8. **`chpst` maps to directives:**

   | `chpst` | slinit |
   |---|---|
   | `-u user` / `-u user:group` | `run-as = user` / `run-as = user:group` |
   | `-u user:group:extra...` | `run-as = user:group` and `supplementary-groups = extra ...` |
   | `-e dir` | `env-dir = dir` |
   | `-o N` | `rlimit-nofile = N` |
   | `-C dir` | `working-dir = dir` |
   | `-n N` | `nice = N` |
   | `prlimit --nofile=N`, `ulimit -n N` | `rlimit-nofile = N` |

   `setsid` in a run script becomes `new-session = yes`: slinit already
   starts a service as a process-group leader, where setsid(1) forks and
   exits, which slinit would see as the service dying.

   Other limits (`-p`, `ulimit -u`) stay as `ulimit` in a helper.
   A limit taken from the conf at run time (`ulimit -n ${MAX_OPEN_FILES:-N}`,
   `chpst -o $MAX_OPEN_FILES`) stays as `ulimit -n` in the helper. If the
   service has `run-as`, the helper cannot raise the hard limit, so the
   service also sets `rlimit-nofile = N:1048576` (the default as the soft
   limit, room under the hard one); a daemon that starts as root and drops
   privileges itself needs no `rlimit-nofile`. An
   environment variable the run script sets (`HOME=...`) is exported in
   the helper, which runs with the service's `run-as` user.

   `-0`, `-1`, `-2` (close stdin, stdout, stderr) become `exec 0<&-`,
   `exec 1>&-`, `exec 2>&-` in the helper, just before the daemon's `exec`.

   **A user, group or directory taken from the conf at run time**
   (`chpst -u "${USER:-_x}"`, `chpst -u $U:$G`, `chpst -C "$HOME"`), and a
   run script that must do root work before dropping to its user (`su -
   postgres -c initdb`, `ln -sf` in `/var/lib`), get **no `run-as`**. The
   helper runs as root, reads the conf, does the root steps, `cd`s where
   `chpst -C` or `cd` went, and ends with setpriv, which matches `chpst -u
   user:group` (one group, environment kept):

       exec /usr/bin/setpriv --reuid "$USER" --regid "$GROUP" --clear-groups \
           -- /usr/bin/daemon $OPTS

   `chpst -u user` with no group is `--regid` of the user's primary group
   (`$(/usr/bin/id -g "$USER")`); `-u user:group:extra` is
   `--groups extra,...` instead of `--clear-groups`. A run-time
   `ulimit -n` then needs no `rlimit-nofile`, since the helper is root. A
   run script that already uses setpriv keeps its line, with the program
   after `--` given by absolute path.

   Anything else (`-U`, `-l`, `-L`, `-m`, `-d`, `-P`, `-/`): stop and
   report it rather than guess.

9. **Dependencies:**
   - a daemon that needs the network gets `depends-on: network.target`
     alone: network.target already depends on local.target. A server that
     listens on a port counts as needing it, loopback-only included;
   - every other daemon gets `depends-on: local.target` (filesystems
     mounted, root read-write), unless it must run earlier in boot, and
     one that uses the network but copes without it adds
     `waits-for: network.target`;
   - a daemon that sets up the network itself (iwd, wpa_supplicant,
     NetworkManager, connman, dhcpcd, dhcp's dhclient, wireguard) gets
     `depends-on: pre-network.target` and `before: network.target`, never
     a dependency on network.target, which would invert the order;
   - a firewall or interface setup that must be in place before any of
     those runs (iptables, nftables, ufw, firewalld, ovs-vswitchd, ifstate)
     gets `before: pre-network.target`, as on Chimera and Artix. A routing
     daemon (frr, bird) gets `depends-on: local.target` only;
   - `sv check <other>` / `sv start <other>` in `run` becomes
     `depends-on: <other>`, using the other daemon's slinit service name;
   - a daemon that talks D-Bus gets `depends-on: dbus`; one that copes
     without the bus (its connection retries, as dnsmasq's does) gets
     `waits-for: dbus`, so a dbus restart does not stop it; one that uses
     it only optionally, through a library (avahi-client), gets neither;
   - services of slinit-services (`logind`, `udevd`, `udev-trigger`) are on
     every Sunlight system and need no `depends` entry.

10. **Runit's other files:** `finish` becomes `finish-command`, `check`
    becomes `ready-check-command` (one command written directly: slinit
    discards a check's output, so `>/dev/null 2>&1` needs no helper;
    otherwise `files/<service>.slinit-check`), `control/t` (runit's stop
    action) becomes `stop-command` (runit never kills after it, slinit does
    after `stop-timeout`: set a longer one if the daemon's own shutdown can
    take long), and a
    `down` file means nothing extra (services are not enabled anyway).
    Two runit idioms have a direct slinit form:
    - a `finish` whose only job is `sv d` on exit code N ("do not restart
      when it exits N") is `normal-exit = N`, which suppresses the restart
      even with `restart = true`;
    - a one-shot kept "up" with `exec chpst -b <name> pause`, whose
      `finish` undoes it, is `type = scripted`: the setup steps are its
      `command` (a helper if more than one), the `finish` logic its
      `stop-command` (one command written directly, or
      `files/<service>.slinit-stop`), and `chpst -b`, which only names the
      process, is dropped. A scripted service has no `log-type` and no
      `restart`.

    A scripted service fails when its setup fails, where runit's `pause`
    kept the service up; say so in the commit. Give it `start-timeout` and
    `stop-timeout` long enough for slow work (runit never timed it out):
    60 seconds as a floor, more for work known to be slow (compiling a
    firewall, starting containers). A
    run script that exits 0 on a missing configuration becomes a scripted
    service whose helper does the same.

    A `finish` that needs a shell (a redirection, a condition) becomes
    `files/<service>.slinit-finish`, run by
    `finish-command = /usr/libexec/slinit/<service>-finish`.

11. **`restart = true`** for a daemon, as runit always restarts one.

12. **Only directives the packaged slinit knows.** Lint with `slinit-check`
    built from the `slinit` version in `srcpkgs/slinit/template` (see
    "Checking a service" below). A directive newer than that version fails
    the service's load on every installed system.

13. **A dependency on another package's service.** `depends-on: <other>`
    fails the service's load when `<other>` is not installed (the boot is
    not affected; the service is never enabled by default). When the
    package exists to run this daemon, add the other package to its
    `depends`; when the service sits in a library subpackage, do not, and
    say so in the commit.

14. **Package scripts that call runit.** A script the package installs
    that runs `sv up <service>` (or `start`, `restart`, `once`...) calls
    `slinitctl start <service>` (or `restart`) instead when `slinitctl`
    exists, keeping `sv` for a runit system; `sv hup`/`sv reload` is
    `slinitctl signal HUP <service>` (slinitctl's own `reload` re-reads the
    service description, it sends no signal). A package document telling
    users to run `/etc/sv/<service>/run` by hand gets the slinit equivalent
    next to it:

        if command -v slinitctl >/dev/null 2>&1; then
            slinitctl start statd
        else
            sv up statd
        fi

15. **What is not a conversion, and is reported instead:** a run script
    that disables itself (`rm /var/service/<service>`, a once-per-machine
    job); one that exits 0 until a runtime condition holds and relies on
    runit's one-second restart loop to poll for it (waiting for X); one
    that relies on a runit-only tool (`utmpset`, `svlogd`, `chpst` beyond
    rule 8) without a slinit equivalent; one whose path the template's own
    install steps contradict (the service is broken in Void too); a runit
    service dir in `files/` that the template never `vsv`s (it is not
    installed); a script the package puts in `/etc/runit/core-services/`
    (a boot-time hook: see rule 21). A package marked `broken=` is
    converted like any other.

16. **Working directory.** runit starts a daemon in `/etc/sv/<service>`;
    slinit does not. Where the run script or the daemon reads files
    relative to its working directory, set `working-dir` to where those
    files really are, and say so in the commit; otherwise none is needed.

17. **Every runit service of a package is converted**, in one commit for
    the package, even if only one was asked for. One that rule 15 reports
    does not hold back the rest: convert the others and name the skipped
    one, with the reason, in the commit body. A `vsv` whose name is a
    variable gets a `vslinit` with the name written out where it can be
    (`vslinit php-fpm8.4`), else the same variable in the same loop.

18. **Syslog daemons need nothing extra.** slinit as PID 1 serves
    `/dev/log`; a syslog daemon started by its own service takes it over.

19. **A header comment:** what the daemon is, which package ships it (the
    subpackage that installs the service, when there is one), and
    how to enable it:

        # sshd -- OpenSSH server (openssh). Not started by default;
        # enable with: slinitctl enable sshd

20. **User services.** A runit service for a user's session (it needs
    `$DISPLAY`, the user's home, or a per-user daemon such as mpd's or
    pipewire's) also, or only, gets `files/<service>.slinit-user`, which
    `vslinit` installs as `/usr/lib/slinit.d/user/<service>`, where
    `slinit --user` (started by turnstile) finds it. The user enables it
    with `slinitctl --user enable <service>`. Same rules otherwise; no
    `run-as`, and `depends-on` only on other user services.

21. **Boot-time hooks** (`/etc/runit/core-services/NN-x.sh`). slinit has no
    such directory, as Chimera and Artix have none. Whatever the hook does
    becomes, in order of preference: a config file the core already reads,
    when the core would do exactly what the hook did; or a `type = scripted`
    service of the package, **enabled** (`vslinit <service> enable`, the
    hook ran on every boot the package was installed), named after the
    hook without its `NN-` prefix. Order it by the hook's number in
    runit's stage 1: `depends-on: early-setup` for 00-04 (before local
    filesystems), `depends-on: filesystems` for the rest, each with
    `before: local.target`; a hook that configures the network takes rule
    9's pre-network.target ordering instead. The core reads only
    `modules-load.d` and `sysctl.d`, not `tmpfiles.d` or `binfmt.d`. A
    best-effort hook (a modprobe loop) may end its helper with `exit 0`,
    as a runit hook never failed the boot; say so in the commit. A hook that duplicates a service
    the package already has (runit-iptables over iptables) is dropped, and
    the package says so.

22. **An env directory** (`chpst -e ./env`) shipped for users to edit is
    installed as files under `/etc/conf.d/<service>.env/` (each in
    `conf_files`), with `env-dir = /etc/conf.d/<service>.env`. A value the
    run script writes there at run time is exported by the helper instead.

23. **Small idioms.**
    - `${OPTS-default}` (no colon) is `${OPTS=default}`: no `OPTS=` line
      before the conf.
    - A lone `1>&2` on the `exec` line or `exec 1>&2` is dropped (both
      streams go to the journal anyway).
    - A variable the sourced conf itself reads under `set -u` is set empty
      before the `.` line, as OPTS is.
    - A code fragment shipped in the runit dir (wpa_supplicant's `auto`)
      is written into the helper.
    - A run script that runs the daemon without `exec` is treated as if it
      had it.
    - A run script that does its job and exits, so that runit's restart
      acts as a timer, keeps `restart = true` and says so in the header;
      slinit stops restarting it after `restart-limit-count`, so the
      commit says that too.
    - Display managers keep `waits-for: udev-trigger`, as gdm does.
    - From slinit 4.2.0 every service gets a default `PATH`; service files
      still use absolute paths, but tools a helper starts may find theirs.

## Finding a binary's path

The tree's lint (`common/hooks/pre-pkg/99-pkglint.sh`) refuses `usr/sbin`
and `usr/local`, so a program a run script calls by bare name is
`/usr/bin/<name>` unless the template puts it elsewhere (`/usr/libexec/...`
is common, and then the run script names the path itself).
`vbin` installs to `/usr/bin`. The tree's gnu-configure defaults
(`common/environment/configure/gnu-configure-args.sh`) and meson helper
(`common/build-helper/meson.sh`) put sbin programs in `/usr/bin` too.
When a template does neither, read its install steps; do not guess.

## What a conversion looks like

Void's `srcpkgs/chrony/files/chronyd/run`:

    #!/bin/sh
    exec 2>&1
    [ -r conf ] && . ./conf
    install -d -m750 -o chrony -g chrony /var/run/chrony
    exec chronyd -n -u chrony ${OPTS}

It sources a configuration file and prepares a directory, so it becomes a
helper, `srcpkgs/chrony/files/chronyd.slinit-run`:

    #!/bin/sh
    set -u
    OPTS=
    [ -r /etc/conf.d/chronyd ] && . /etc/conf.d/chronyd
    /usr/bin/install -d -m750 -o chrony -g chrony /var/run/chrony
    exec /usr/bin/chronyd -n -u chrony ${OPTS}

and the service, `srcpkgs/chrony/files/chronyd.slinit`:

    # chronyd -- keeps the clock right (chrony). Options: OPTS in
    # /etc/conf.d/chronyd.
    type = process
    command = /usr/libexec/slinit/chronyd
    depends-on: local.target
    waits-for: network.target
    restart = true
    log-type = journal

The template gets `vslinit chronyd` after `vsv chronyd` (`vslinit chronyd
enable` here only because chronyd is in the default set), and its revision
goes up by one. `OPTS=` before the `.` keeps `set -u` from failing when the
file does not exist; `exec 2>&1` is gone, because `log-type = journal`
takes both streams.

## Checking a service

Before a commit, every changed service must pass the linter built from the
packaged slinit, together with slinit-services' services (which define
`local.target`, `network.target` and the rest):

    mkdir -p /tmp/svc && cp srcpkgs/slinit-services/files/services/* /tmp/svc/
    for f in srcpkgs/*/files/*.slinit; do
        [ -L "${f%%/files/*}" ] && continue   # a subpackage's symlinked dir
        cp "$f" /tmp/svc/"$(basename "$f" .slinit)"
    done
    slinit-check -d /tmp/svc <service>

A warning that a command's binary, a `run-as` user, or a `working-dir`
the package's `make_dirs` creates does not exist is
expected on a machine without the package, for the service and for
slinit-services' own helpers;
every other warning or error is a failure. Two services of the same name in
different packages would overwrite each other in that directory; check
each in its own if a name repeats. Helpers are committed with mode 755. Then build
the package (`./xbps-src pkg <package>`) and check with `xbps-query -f` that
`/usr/lib/slinit.d/<service>` is in it.

## One commit per package

Subject `<package>: add the slinit service <service>`; the body says what
the service does differently from the runit one, if anything, and why. A
later change to a `.slinit` file of a published package bumps `revision`,
or installed systems never receive it.
