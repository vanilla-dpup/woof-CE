# VanillaDpup / woof-CE Build System

## Overview

This repository is a fork of **woof-CE**, the build system for **Puppy Linux** derivatives. It builds **VanillaDpup ("Dpup") 12.0**, a Puppy derivative assembled from **Debian** binary packages. Its stated goal is a DebianDog-like system — highly Debian-compatible, portable, modular, hackable, and lightweight, with the core features of Puppy Linux.

Rather than remastering an existing image, the build bootstraps a minimal Debian root filesystem, installs a curated package set with `apt`, compiles some components from source, assembles a layered Puppy root filesystem, builds a kernel and initramfs, and emits bootable disk images plus a set of compressed filesystem layers.

The result follows the classic Puppy model: the OS lives in read-only compressed image layers stacked under a writable layer (an `overlayfs` union), can run entirely from RAM, and persists changes to an optional **save** layer. PID 1 is a custom minimal C program and the session is Wayland-based. The base stays small: firmware, locales, and documentation are split into separate layers, while the development toolchain lives only in the build environment and is not shipped.

## Relationship to upstream woof-CE

| Area | Upstream woof-CE | This fork |
|------|------------------|-----------|
| Structure | General-purpose **meta** build system; source split into `woof-code` (engine), `woof-arch` (per-architecture prebuilt binaries), and `woof-distro` (per arch/distro/version config). A `merge2out` step merges a chosen combination into a fresh `woof-out_*` directory. | **Flattened, single-target** derivative: one already-merged tree dedicated to building VanillaDpup, with the scripts and config at the repository root. No `merge2out` and no `woof-code`/`woof-arch`/`woof-distro` split. |
| Build stages | Four scripts run: `0setup`, `1download`, `2createpackages`, `3builddistro`. | Reshaped pipeline: `0setup` and `2createpackages` are gone (the package step folds into `1download`), a dedicated `2buildkernel` is added, and `3builddistro` runs last. |
| Build host | Requires running on a Puppy host with devx (or `run_woof`). | Builds inside a plain Debian container/chroot. |
| Build isolation & reproducibility | The package and kernel stages run on the **host** with host tools (the kernel-kit compiles with the host's `gcc`/`make`); `merge2out` advises building on a recent woof-CE Puppy (or `run_woof`), so the output depends on the host environment | Everything compiles inside **chroots** over the `debootstrap` Debian base — the kernel and the petbuilds build in the `devx` chroot — so the host needs only `debootstrap` + root (CI uses a plain `debian:trixie-slim` container). Output is determined by the pinned suite + the repo (the distro's own toolchain), and the built distro can rebuild itself |
| Deliverable / output format | A bootable **ISO** (`mk_iso.sh`: `mkisofs`/`xorriso`, made **isohybrid** so it boots from CD or USB); the SFS layers sit alongside in `woof-output-*`. Install = boot the live ISO, then frugal-install | A bootable **flash-drive disk image** (`.img`) written by `bootflash` over a loop device — a 2 GB sparse image (FAT32 boot + ext4/F2FS data holding the SFS set, `vmlinuz`, `initrd.zst`, microcode). **No ISO/isoboot**; writing the image to a drive *is* a `bootflash` install |
| Installers | **Puppy Universal Installer** (frugal/full disk installer) and **Bootflash** (flash drive installer). Both are de facto superseded by **FrugalPup** (BIOS + 32/64-bit UEFI with Secure Boot using prebuilt shim and GRUB2 + MOK, FAT32 boot + FAT32/F2FS/ext3/ext4 data partitions), maintained outside of woof-CE. | Only a rewritten and extended [bootflash](rootfs-skeleton/usr/local/sbin/bootflash) (FAT32 boot + ext4/F2FS data partitions, configures bootloader and save layer). |
| Bootloaders & boot-sector provenance | BIOS: **isolinux** in the ISO, plus a prebuilt **`wee.mbr`** blob bundled in the skeleton (`/usr/share/boot-dialog/wee.mbr`) written by the on-device installers; grub4dos (`grldr`) is offered in the boot menu. UEFI: **GRUB2** bundled with **FrugalPup** | BIOS: `syslinux` from Debian. UEFI: **efilinux** built from source. |
| Compat bases | Several compat bases (Slackware, Ubuntu, Debian, Devuan, Void) across multiple architectures. | Debian/Devuan only; primarily x86_64. |
| Root filesystem (`/`) construction | Built **from `rootfs-skeleton`** in traditional Puppy style — the skeleton ships the base config itself (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/fstab`, `/etc/inittab`, sysvinit `rcN.d`, with per-compat-distro variants like `passwd.debian`); `bdrv.sh` then layers a Debian/Devuan base on top for compatibility. | Starts from a real `debootstrap` Debian/Devuan base, which owns `/etc/passwd`, `/etc/shadow`, etc.; `rootfs-skeleton` is overlaid **conflict-free** (ships no `/etc/passwd` or `/etc/shadow`), adding only Puppy-specific files (`rc.d`, `init.d`, `profile.d`, `skel`, `hostname`, `eventmanager`) and keeping any overrides in `/usr/local`. |
| Base utilities (coreutils, util-linux) | Replaced with **busybox** symlinks (`busybox_symlinks.sh`) to save space | Kept as the real Debian packages (no busybox symlinking), to preserve upstream-distro compatibility |
| Package sources | Compat-distro repos + Puppy PET repos + prebuilt `woof-arch` binaries | `debootstrap` + `apt`, plus components compiled from source (petbuilds); no PET repos, no prebuilt-binary directory |
| Package management | `apt` is present (`bdrv.sh`), but **every installed package is held** ("prevent updates"): Puppy overrides some distro files in place (e.g. `/usr/sbin/poweroff`), so an `apt upgrade` would restore the originals and break the system — holding everything blocks that. PPM/petget is the package GUI | `apt` is the package manager with **nothing held**: overrides instead live under `/usr/local/{,s}bin` (outrank `/usr/{,s}bin`, owned by no package), so `apt upgrade` is safe and supported (only kernel/firmware are pinned to a suite). PPM is gone, `petget` only for limited `.pet` |
| Developer layer (`devx`) | A `devx` SFS (compilers/headers) is built and shipped as an optional layer | No `devx` SFS shipped — `devx` is only the build chroot; the running system installs dev tools via `apt`, and a `kbuild` SFS ships for out-of-tree modules |
| SFSs | Uses **squashfs**, each mounted through a loop device (`/dev/loopN`) | Uses **erofs**, allowing direct file-backed mounting to avoid loop device overhead. (With squashfs fallback.) |
| Union | aufs (or overlayfs) | overlayfs only |
| Kernel build (`kernel-kit`) | ~1100-line `build.sh`: downloads a **mainline kernel.org** kernel and patches it — **aufs** plus bundled patches under `patches/` (and a 500 Hz `Kconfig.hz` tweak); uses a full per-version/arch `DOTconfig` (~10,000 lines) and a **firmware picker**; compiles on the host with host tools | ~80-line `build.sh`: rebuilds **Debian's `linux-source` unpatched** (installed into `devx`), merging only a ~130-line `debian-diffconfigs/<suite>` fragment over Debian's base config via `merge_config.sh`; no aufs (overlayfs only), no firmware picker (fdrv comes from Debian packages); compiles **inside the `devx` chroot** so it shares the distro's toolchain |
| initrd build | `build.sh` downloads a prebuilt tarball of ancient static binaries from `initrd_progs`; gzip cpio | `build.sh` assembles the initrd from the freshly built rootfs's own binaries (busybox + fsck/mount tools + libs via `ldd`); zstd cpio |
| Boot chain & login | **busybox `init`**, reading `/etc/inittab` to run `rc.sysinit` and `/usr/sbin/plogin` on `tty1`. `plogin` does first-boot setup (home dir, busybox SUID applets, password prompt) and execs `getty -n` with `/bin/autologin` (runs a passwordless `login -f`). The login shell then starts X.Org via `xwin`. Runs as **root**; the non-root-user feature (`finn`/`loginmanager`) was broken and removed (commit 9b229cf), leaving it root-only. | [Custom minimal `init`](rootfs-petbuilds/init/init.c) runs [rc.sysinit](rootfs-skeleton/etc/rc.d/rc.sysinit), then opens a native Linux-PAM login session on `/dev/console` directly for the unprivileged `spot` user. The profile shell launches the Wayland compositor. |
| Swap | `loadswap_func` prefers a swap partition, then a swap file, using zram (~full RAM) only as a last resort; can be disabled | zram is always created first (lz4, ≈½ RAM capped at 4 GiB); a swap partition/file is added as slower fallback |
| SFS RAM caching (`pfix=copy`/`ram`) | SFSs are **copied** into a tmpfs ramdisk in the initrd, **synchronously** (blocks boot); that RAM is **unreclaimable** but the boot media **can** be unplugged if running in PUPMODE 5. | [sfslock.c](rootfs-petbuilds/sfslock/sfslock.c) **locks the SFSs' pages in the page cache** from [rc.sysinit](rootfs-skeleton/etc/rc.d/rc.sysinit), **asynchronously** (boot continues); memory is **reclaimed automatically** under memory pressure (PSI/OOM) but the boot media **cannot** be unplugged. |
| Storage / TRIM awareness | - | Uses `discard_max_bytes` to classify the device: auto-enables SFS page-cache caching only on non-TRIM (slow flash) media, and runs a weekly `fstrim` service (`/etc/init.d/trim`) on TRIM-capable save devices |
| Save file filesystem | `ext2/3/4` save files (user-chosen). | Only `ext4`, with journaling disabled to boost flash performance and lifespan, and dynamic space allocation (sparse file) for fast creation and more flexible use of free space. |
| Save encryption | Only for save files, using **LUKS** (`cryptsetup`). | For save files **and folders** using **fscrypt** (via [pfscrypt](rootfs-petbuilds/pfscrypt/pfscrypt.c)), **whole save or home directory only** (user-chosen). |
| Save creation | First-shutdown prompt (triggered by `rc.shutdown` via `shutdownconfig`). | Explicitly via [pupsave](rootfs-skeleton/usr/local/sbin/pupsave) (with option to merge current session), or pre-created by [bootflash](rootfs-skeleton/usr/local/sbin/bootflash) installer. |
| [save2flash](rootfs-skeleton/usr/local/sbin/save2flash) | Uses `cp -a` to rewrite modified files **entirely**. Highly inefficient for large/growing files (e.g., SQLite WAL, browser profiles, logs), resulting in slow sync speeds and severe write amplification that degrades flash media longevity. | Uses [psnapcp](rootfs-petbuilds/psnapcp/psnapcp.c) to optimize writes: compares files quickly in 512-byte chunks (`mmap` + `MADV_SEQUENTIAL`), writes only modified blocks, preallocates size or truncates (`posix_fallocate`/`ftruncate`) to reduce rewriting and append zero blocks quickly, avoids read-induced writes (`O_NOATIME`), and syncs disk only if needed. Dramatically reduces write volume (often to < 1%). |
| Desktop privileges | Runs as **root**; `spot` only for select apps (a non-root-user login existed but was broken and removed) | Desktop and apps run as the unprivileged **`spot`** user, with `spot-pkexec` to escalate to root on approval |
| Desktop | X11 (JWM) | Wayland only (labwc, or dwl) |
| File manager | ROX-Filer (default; `pcmanfm`/`spacefm` also available) | zzzfm (the antiX SpaceFM fork), patched for Wayland/layer-shell |
| Desktop partition icons | Drive icons on the ROX-Filer pinboard (`PuppyPin`): a one-shot startup script seeds them, and a udev rule runs `frontend_change` per block event to maintain them (`pup_event_frontend_d` is not a persistent daemon — it just starts `udevd` and exits) | A small persistent libudev daemon (`particonsd`) watches block uevents and runs `particons` to regenerate standard `.desktop` files in `~/Desktop`, each opened with `zzzfm` |
| Menu & cache updates | `rc.update` (~350 lines) refreshes desktop/system caches on version/SFS change and **rebuilds the WM menu inline via `fixmenus`**; `fixmenus` is also invoked from `sfs_load`, `menumanager`, `logout_gui`, etc. | `rc.update` (~100 lines) refreshes only caches and never touches menus; menu rebuilds are event-driven — `fixmenusd` (an inotify daemon) watches `/usr/share/applications` and runs `fixmenus` on any change (plus a manual "Rebuild Menu" in `logout_gui`, and one run at build time) |
| Default app associations | `pmime` + `/etc/pmime.conf`, a shipped `mimeapps.list`, `default*` wrapper scripts, and the `puppyapps` chooser GUI | Standard `mimeapps.list` |
| Session D-Bus | Two `dbus-launch --exit-with-x11` session buses from `.xinitrc` — one for root, one for `spot` (its address shared via `/tmp/.spot-session-bus` and re-exported by `run-as-spot`) — because the desktop is root but some apps run as `spot` | A single session bus for the whole single-user (`spot`) session, via `dbus-run-session` wrapping the compositor launcher |
| Audio (PipeWire) | Started from `.xinitrc` as `spot` via `run-as-spot` (`pipewire` → `pipewire-pulse` → `wireplumber`); spot's socket is symlinked into `/run/pipewire` and `PULSE_SERVER`/`PULSE_COOKIE` are exported so root and `spot` share one instance | Started by the compositor launcher as the session `spot` user (`pipewire` → `pipewire-pulse` → `wireplumber`) using the session's own `XDG_RUNTIME_DIR`; no cross-user sharing or symlinks |
| `firewall_ng` | `iptables`/`ip6tables`; **~1500**-line "block bad packets" script with router/**server-style** egress filtering; **not enabled** by default | `nftables`; **~500**-line default-drop-input allowlist, **endpoint-focused**; **enabled** by default; blocks mDNS/SSDP/NAT-PMP |
| `pup-advert-blocker` | Appends megabytes of blocklists to `/etc/hosts`, bloating the save layer on blocklist update and slowing down the resolver's sequential scanning. | Uses [nss-adlist](rootfs-petbuilds/pup_advert_blocker/nss-adlist.c) for fast $O(\log n)$ lookup in a sorted array of XXH3 hashes (8 bytes per domain). |
| MAC randomization | - | On a NIC's first bring-up by default (`mac_changer` + udev rule) |
| Kernel sysctl hardening | - | Ships `/etc/sysctl.d/99-puppy.conf` (`kptr_restrict=2`, `yama.ptrace_scope=2`, `unprivileged_bpf_disabled`, `bpf_jit_harden`, `kexec_load_disabled`, `sysrq=0`, network redirect/`rp_filter` hardening), applied via `sysctl --system` |
| End-user help | HTML files in `/usr/share/doc` (`home.htm`, `HOWTO-*.htm`, CSS), opened in the browser by `puppyhelp` | Markdown files in `/usr/local/share/doc/puppy` plus an auto-generated `index.md`, opened in `mdview` by `puppyhelp` |

## Capabilities and variants

`DISTRO_VARIANT` selects a build profile, gating large blocks of the package table and the from-source build list:

| Variant       | Description |
|---------------|-------------|
| *(default)*   | Full desktop around the **labwc** compositor, with browser, office, media, printing, and accessory apps. |
| `dwl`         | Desktop around the **dwl** compositor (with `yambar`, `tofi`) instead of labwc. |
| `mini`        | Smaller desktop; drops the heavier app set (printing, media editors, office, games). |
| `barebones`   | Desktop core only; drops most apps and the browser. |
| `cli`         | No graphical stack; command-line only. |

`DISTRO_TARGETARCH` (`x86_64`/`x86`/`arm`/`arm64`) maps to the Debian architecture and gates firmware and bootloader selection; BIOS images are built for x86/x86_64, UEFI for x86_64/arm64. `DISTRO_BINARY_COMPAT` selects Debian or Devuan, `DISTRO_COMPAT_VERSION` the suite (e.g. `unstable`), and `DISTRO_COMPAT_KERNEL_VERSION` may pin the kernel and firmware to a different suite via generated `apt` preferences.

Optional features: encrypted persistent storage (per-directory `fscrypt` via `pfscrypt`, Argon2-derived key); ad blocking via an NSS module; firmware and CPU microcode; a from-source kernel plus a shipped `kbuild` layer (kernel source/headers) for building out-of-tree modules on the running system; and BIOS/UEFI images. Unlike upstream, there is no shipped `devx` SFS — the build toolchain exists only in the build chroot, and the running Debian-based system installs development tools through `apt` if needed.

## Build pipeline

Three numbered top-level scripts run in order. Each sources `_00func` and calls `clearenv`, which re-execs the script in a clean, fixed environment (locale, XDG paths, `PATH`, non-interactive `apt`), and all three require **root** (they `chroot`, `mount`, and use loop devices). Intermediate state lives under `sandbox3/`, downloads are cached under `local-repositories/`, and output lands in `woof-output-<prefix>-<version>/`.

**`1download`** — builds the package base with `debootstrap` and `apt`: debootstraps a minimal Debian (`--variant=minbase`, tarball cached) into `sandbox3/rootfs`; writes `apt` sources/config (no Recommends/Suggests, chosen mirror/suite, optional separate kernel suite with pins, LibreWolf via `extrepo` on desktop variants); installs the runtime package set from `DISTRO_PKGS_SPECS`; copies `rootfs` to `devx` and adds dev packages plus the Linux kernel source and build deps; caches `.deb` archives. Result: `rootfs` (runtime base) and `devx` (the same plus toolchain and kernel source).

**`2buildkernel`** — overlay-mounts a writable layer over `devx`, chroots in, and runs `kernel-kit/build.sh`, so the kernel is built against the target's own toolchain and libraries. See [Kernel](#kernel).

**`3builddistro`** — assembles the distribution: copies `rootfs` to `rootfs-complete`, generates locales, and overlays `rootfs-skeleton/`; creates the unprivileged `spot` user; applies the fixup templates and prebuilt rootfs packages; builds and installs the petbuilds; marks packages so `apt autoremove` prunes anything unwanted (libraries used by petbuild binaries are protected); splits out firmware (`fdrv`), locales/large fonts (`nlsx`), docs/man/help (`docx`), and CPU microcode (early-load cpio); builds the initramfs and pulls in the stage-2 kernel artifacts; packs each tree into an **erofs** SFS layer; and builds the disk images.

## Configuration model

| File | Role |
|------|------|
| `DISTRO_SPECS` | Distro name, version, file prefix, target arch, compat distro/suites, and the canonical SFS layer filenames. Installed into the image as `/etc/DISTRO_SPECS`. |
| `DISTRO_PKGS_SPECS` | The package table (`PKGS_SPECS_TABLE`): which Debian packages are installed and how their files split across layers. |
| `_00build.conf` | The from-source build list (`PETBUILDS`) and SFS compression flags (`SFSCOMP`), varying by variant/suite. |
| `_00func` | The root check and `clearenv`. |

Each `PKGS_SPECS_TABLE` row is a `|`-separated record whose key fields are a generic name, the Debian package names it maps to, and a **split rule** distributing files among outputs: `exe` (base layer), `dev` (the build-only `devx` chroot, not shipped), `doc` (`docx`), `nls` (`nlsx`). A `>` redirects a category (e.g. `dev>null` discards dev files, `exe>dev` makes a package build-only). Variant and architecture checks append whole blocks, so the effective package set is a function of `DISTRO_VARIANT` and `DISTRO_TARGETARCH`.

## From-source builds (petbuilds)

Components not taken from Debian are compiled by `support/petbuilds.sh`, driven by `PETBUILDS`. Each lives under `rootfs-petbuilds/<name>` as a `petbuild` script defining a `download` function (fetches source, typically with `curl`; may be a no-op if source ships in the directory) and a `build` function (compiles and installs into the staging root using `CC`/`CFLAGS`/`LDFLAGS`/etc.). Optional files: patches, a `sha256.sum`, embedded C sources/headers, a `DOTconfig`, a `README.md`, and a `pinstall.sh` (post-install fixup run inside the target).

Each builds in an overlay `chroot` stacked over `devx` and the in-progress `rootfs-complete`, with `/proc`, `/sys`, `/dev`, and a tmpfs `/tmp` bind-mounted and shared `ccache`. Flags target small binaries (optimization, section GC, stripping), and outputs are stripped and pruned of static/libtool archives, pkg-config data, headers, and Python bytecode. Output is cached under `petbuild-output/<name>-<hash>` (hash of the package specs plus the recipe), with a `<name>-latest` symlink, so repeated builds skip unchanged components.

Four foundational tools are always built first, alongside Puppy-specific utilities:

| Component | Role |
|-----------|------|
| `init` | Minimal C PID 1. Replaces the busybox init/getty/login chain: runs `/etc/rc.d/rc.sysinit`, then repeatedly opens a PAM login session on `/dev/console` for an unprivileged user (`spot` by default, overridable via the `puser` boot parameter); reboots/powers off on signals. |
| `pfscrypt` | Tiny C wrapper over kernel `fscrypt` to lock/unlock directories; Argon2-derived key. |
| `sfslock` | Maps an SFS into memory and locks its pages into RAM to speed slow-media access; raises its own OOM score and yields under memory pressure. |
| `psnapcp` | Fast save-layer file sync used by `snapmergepuppy`. Rather than rewriting whole files, it first resizes the destination to match the source (shrinking it, or preallocating/growing it), then writes only the blocks that actually differ and syncs metadata. For files that mostly grow or change only near the start (headers) or end — e.g. SQLite WAL files written by browsers — this can cut writing to as little as ~1% of the file. |
| `pup_advert_blocker` | NSS module blocking ad domains by binary search over a sorted array of hashed names, avoiding a giant `/etc/hosts`. |
| `rtclock` | eBPF that stops ConnMan writing the hardware clock (avoiding conflicts with other OSes); the software clock is synced from RTC at boot. |
| `notification-daemon-stub` | A no-capability notification daemon for apps that expect one, without the cost of a real one. |
| `ram-saver`, `psuspend`, `spot-pkexec`, `fixmenusd` | RAM tweaks; SUID suspend tool; a minimal pkexec letting `spot` run actions as root on approval; an inotify watcher that rebuilds menus on app changes. |

Variant-specific petbuilds add the compositors and helpers (`labwc-puppy`, `xdg-puppy-labwc`, or `dwl`/`yambar-dwl`), the `yad` dialog tool, the `zzzfm` file manager, and desktop apps.

## Package fixups and prebuilt overlays

Two mechanisms add or adjust content beyond a clean Debian install:

- **`packages-templates/`** — `<package>_FIXUPHACK` snippets. For each installed Debian package with a matching template, the template is sourced against the staging tree; it can patch config, add symlinks, generate defaults, or emit a `pinstall.sh` run inside the target (e.g. shell defaults, audio/network config, default browser, desktop launchers).
- **`rootfs-packages/`** — ready-made filesystem trees copied verbatim, each with an optional `pinstall.sh`: ACPI handling (`acpid_busybox`), the firewall (`firewall_ng`), the package manager front-end (`petget`, which gives limited `.pet` support now that PPM is gone), the MAC-randomization tool (`mac_changer`), and the ad blocker's runtime files.

## The runtime root (`rootfs-skeleton`)

`rootfs-skeleton/` is the Puppy-specific layer overlaid onto the Debian base, holding boot/shutdown logic, save/SFS tooling, and session helpers.

**Boot/shutdown.** The custom `init` (PID 1) runs `/etc/rc.d/rc.sysinit` — mounts core filesystems, starts udev, loads modules, sets up swap/zram, optionally caches SFS layers into RAM (via `sfslock`), refreshes caches with `rc.update`, starts services with `rc.services`, runs `rc.local`. It then opens a console login session for `spot`, whose profile starts the Wayland session, so the compositor and apps run as a regular user, with `spot-pkexec` escalating to root on approval. `rc.shutdown` stops services, unloads SFS layers, optionally saves the session (merging RAM changes down to the save layer), remounts read-only, and unmounts.

**Save behavior (PUPMODE).** Set by the initramfs, it governs persistence; only three modes are supported:

| PUPMODE | Meaning |
|---------|---------|
| 5  | Live / no save — changes live only in RAM. |
| 12 | Automatic persistency: the save file/folder is the writable layer; changes go straight to disk. |
| 13 | On-demand persistency: changes accumulate in a RAM (tmpfs) layer, snapshotted to the save layer on demand or at shutdown. |

`snapmergepuppy` performs the RAM-to-disk merge (via `psnapcp`); `save2flash` triggers it on demand, and `rc.shutdown` runs it for PUPMODE 13 (after an optional prompt). Saves are created explicitly: `pupsave` makes a save file or folder and, when run live (PUPMODE 5), can immediately merge the current session into it via `snapmergepuppy`, while the installer `bootflash` only creates an empty save on the target drive. There is no first-shutdown prompt to create a save — under PUPMODE 5 a shutdown simply discards the session — which keeps non-persistent use unobtrusive. Save files use ext4 without journaling, are sparse where possible, and (like save folders) support per-directory `fscrypt` encryption. Files spilled to the save layer by `apt upgrade` or metadata-only changes are cleaned up where possible to keep it small.

**SFS and session.** At boot the initrd auto-loads every `.sfs` under the partition root (and `psubdir`) on both the boot and save partitions — no manual queuing, no limit on count or names — sorted numerically so the user controls stacking order (the traditional `*drv` order is preserved). At runtime, `sfs_load` adds or removes individual SFSs without rebuilding the overlay: it mounts the SFS and merges its contents into the live filesystem via a symlink farm (tracked under `/var/lib/sfs_load.overlay/`), then refreshes caches with `rc.update`. `bootflash` writes Puppy onto a disk/partition. On desktop variants the Wayland session runs the variant's compositor; `xdg_autostart.sh` launches autostart entries, small yad-based tools configure input/keyboard/autostart/services (plus a `kanshi` display-profile generator and a screenshot/recording tool), and `logout_gui`/`wmexit` handle session exit.

## Initramfs

`initrd-progs/` builds the early-boot initramfs. `build.sh` assembles a small root from `0initrd/` plus busybox and a few statically-needed tools (mount, `lsblk`, `pfscrypt`, and the ext4/f2fs/fat/exfat fsck and resize utilities) with their libraries, packed as a zstd cpio. The `0initrd/init` early userspace:

1. Mounts pseudo-filesystems and reads `/DISTRO_SPECS`.
2. Discovers the boot media (by boot parameter or by searching for the main SFS), waiting for slow storage.
3. Mounts and stacks the SFS layers (main `puppy` plus any `bdrv`, `ydrv`, `adrv`, kernel-source/module, firmware, locale, and doc layers).
4. Builds the union root: overlay plus a tmpfs writable layer.
5. Attaches the save file/folder, picking the PUPMODE by media type; optionally decrypts directories with `pfscrypt`, runs fsck, and resizes the save file.
6. Records boot state, then `switch_root`s into the real root, executing `/usr/local/sbin/init`.

Boot codes are pared down: the Puppy partition is given only as `pupsfs=$UUID` and the save partition only as `psave=$UUID` (the older `pdrv`, `SAVEMARK`/`SAVESPEC`, `pimod`, `pwireless`, etc. are gone), plus `psubdir` and `pfix` flags (RAM-only, fsck, drop-to-shell, no-copy). zram swap is always enabled, with a swap file as slower fallback.

## Kernel

`kernel-kit/` builds a Fatdog-style "huge" kernel — most storage, USB, input, and filesystem drivers are built in so it boots from a wide range of media without external modules. `build.sh` extracts Debian's `linux-source`, takes Debian's config for the target arch as a base, and merges the `debian-diffconfigs/<suite>` fragment on top via the kernel's `merge_config.sh`. The fragments enable what Puppy needs and trim the rest: `overlayfs`, `squashfs`/`erofs`, loop devices, broad ATA/SATA/USB/MMC/NVMe support, NLS/codepages, unsigned modules, quiet boot.

It produces `vmlinuz`, a kernel-modules SFS (the runtime `zdrv` layer), a `kbuild` SFS of trimmed source/headers for out-of-tree modules (assembled by `kbuild.sh`), a BTF-derived `vmlinux.h` (used by the eBPF petbuilds), and the kernel config and `System.map`. Stage 3 consumes these to produce the final layers.

## Output artifacts

Into `woof-output-<prefix>-<version>/`:

- **SFS layers** (erofs): the main `puppy` root, `fdrv` (firmware), `zdrv` (kernel modules), `nlsx` (locales/fonts), `docx` (documentation), and the `kbuild` source layer; `ydrv`/`adrv`/`bdrv` names are reserved for additional layers.
- **`vmlinuz`** and the **initramfs** (`initrd.zst`), plus the microcode cpio.
- **Bootable disk images**: a BIOS image (syslinux) and/or UEFI image (efilinux), each a 2 GB sparse image written by `bootflash` over a loop device. There is no ISO/`isoboot`; the output is a flash-drive image, and writing it to a flash drive is equivalent to a `bootflash` install. The layout is a small FAT32 boot partition plus a large ext4 (no journaling) or F2FS data/persistency partition; `bootflash` also lets the user pick the PUPMODE, creating an empty save file/folder for 12 or 13.

SFS images are compressed with zstd (or lz4hc for some suites), per `SFSCOMP`. EROFS layers use the kernel's file-backed mode for cache efficiency; squashfs is supported as an alternative.

## Codebase structure

| Path | Role |
|------|------|
| `1download` | Stage 1: debootstrap + apt; builds `rootfs` and `devx`. |
| `2buildkernel` | Stage 2: chroot into `devx` and build the kernel. |
| `3builddistro` | Stage 3: assemble layers, build petbuilds and initramfs, make images. |
| `_00func` | Root check and `clearenv`. |
| `_00build.conf` | `PETBUILDS` list and SFS compression flags. |
| `DISTRO_SPECS` | Distro identity, arch, compat suites, SFS layer filenames. |
| `DISTRO_PKGS_SPECS` | Package table and split rules. |
| `support/petbuilds.sh` | Driver for from-source component builds. |
| `support/pc_image.sh` | Builds the BIOS/UEFI disk images. |
| `rootfs-petbuilds/` | One directory per from-source component. |
| `packages-templates/` | Per-Debian-package fixup snippets (`*_FIXUPHACK`). |
| `rootfs-packages/` | Prebuilt filesystem trees copied into the image. |
| `rootfs-skeleton/` | Puppy runtime overlay: boot/shutdown, save/SFS tools, session. |
| `initrd-progs/` | Initramfs contents (`0initrd/`) and its build script. |
| `kernel-kit/` | Kernel build script, `kbuild` helper, per-suite config fragments. |
| `.github/workflows/` | CI: kernel builds, distro builds, release packaging. |
