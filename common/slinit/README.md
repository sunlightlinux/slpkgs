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
| Default configuration, if the runit service had a `conf` | `files/<service>.conf` | `/etc/conf.d/<service>` (a `conf_files` entry) |

`vslinit <service>` installs the first two; see `Manual.md` (at the top of the tree). Put the
`vslinit` line directly after the `vsv` line of the same service, in the
same function, and bump `revision`. A subpackage that `vmove`s
`etc/sv/<service>` also moves `usr/lib/slinit.d/<service>` (and, with
`enable`, `usr/lib/slinit.d/boot.d/<service>`).

`<service>` is the name `vsv` uses, so a daemon is enabled by the same name
under either init. Never invent another one.

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
   POSIX `sh`, `set -u`, absolute paths, ending in
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
   `files/<service>/conf`, copy it to `files/<service>.conf`, install it with
   `vinstall ${FILESDIR}/<service>.conf 644 etc/conf.d <service>`, and add
   `/etc/conf.d/<service>` to `conf_files`. Do not use `env-file`: it reads
   `KEY=value` literally, and Void's files are shell (`OPTS="-x"` would
   keep the quotes).

6. **Output goes to the journal: `log-type = journal`** on every
   `type = process` service. Drop runit's `exec 2>&1` and the `log/`
   service; `slinit-journalctl -u <service>` replaces `vlogger`.

7. **Preparing a directory:** `install -d -m 0755 -o u -g g /run/x` becomes

       pre-start-command = +/usr/bin/install -d -m 0755 -o u -g g /run/x

   The `+` runs it as root even with `run-as`.

8. **`chpst` maps to directives:**

   | `chpst` | slinit |
   |---|---|
   | `-u user` / `-u user:group` | `run-as = user` / `run-as = user:group` |
   | `-u user:group:extra...` | `run-as = user:group` and `supplementary-groups = extra ...` |
   | `-e dir` | `env-dir = dir` |
   | `-o N` | `rlimit-nofile = N` |
   | `-C dir` | `working-dir = dir` |
   | `-n N` | `nice = N` |

   Anything else (`-l`, `-L`, `-m`, `-d`, `-p`, `-P`, `-0`..`-2`): stop
   and report it rather than guess.

9. **Dependencies:**
   - every daemon gets `depends-on: local.target` (filesystems mounted,
     root read-write), unless it must run earlier in boot;
   - a daemon that needs the network gets `depends-on: network.target`, one
     that copes without it `waits-for: network.target`;
   - `sv check <other>` / `sv start <other>` in `run` becomes
     `depends-on: <other>`, using the other daemon's slinit service name;
   - a daemon that talks D-Bus gets `depends-on: dbus`.

10. **Runit's other files:** `finish` becomes `finish-command`, `check`
    becomes `ready-check-command` (through a helper if it is a script), a
    `down` file means nothing extra (services are not enabled anyway).

11. **`restart = true`** for a daemon, as runit always restarts one.

12. **Only directives the packaged slinit knows.** Lint with `slinit-check`
    built from the `slinit` version in `srcpkgs/slinit/template` (see
    "Checking a service" below). A directive newer than that version fails
    the service's load on every installed system.

13. **A header comment:** what the daemon is, which package ships it, and
    how to enable it:

        # sshd -- OpenSSH server (openssh). Not started by default;
        # enable with: slinitctl enable sshd

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
    install -d -m750 -o chrony -g chrony /var/run/chrony
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
    for f in srcpkgs/*/files/*.slinit; do cp "$f" /tmp/svc/"$(basename "$f" .slinit)"; done
    slinit-check -d /tmp/svc <service>

A warning that the command's binary does not exist is expected on a machine
without the package; every other warning or error is a failure. Then build
the package (`./xbps-src pkg <package>`) and check with `xbps-query -f` that
`/usr/lib/slinit.d/<service>` is in it.

## One commit per package

Subject `<package>: add the slinit service <service>`; the body says what
the service does differently from the runit one, if anything, and why. A
later change to a `.slinit` file of a published package bumps `revision`,
or installed systems never receive it.
