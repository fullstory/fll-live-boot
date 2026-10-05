# fll-live-boot

Boot-time glue for [F.U.L.L.S.T.O.R.Y](https://github.com/fullstory) live media —
both the early userspace (initramfs) and the systemd boot sequence of the running
live system. This is the merger of the formerly separate `fll-live-initramfs` and
`fll-live-initscripts` source packages, which were intrinsically coupled (the
`fll-live-utils` binaries were built by initscripts but consumed only by the
initramfs).

## Repository layout

| Path | Contents |
|------|----------|
| `initramfs/` | initramfs payload: `fll.initramfs`, `fll.shutdown`, and the `dracut/` module |
| `initscripts/` | running-system payload: systemd-helper scripts (`share/`, including the `90-fll.rules` polkit grant that `fll_home` deploys to `/run` only for the passwordless non-homed user), and the shutdown `/run` remount helper |
| `utils/` | `fll_login` (getty helper) |
| `debian/` | packaging for all binary packages |

## Binary packages

One source, the same five binary packages as before:

| Package | Arch | Contents |
|---------|------|----------|
| `fll-live-initramfs` | all | initramfs glue (`initramfs/`); depends on `fll-live-utils` |
| `fll-live-initscripts` | all | systemd units and helper scripts (`initscripts/`) |
| `fll-live-initscripts-networkd-dummy` | all | default `wired.network` (created in postinst) |
| `fll-live-utils` | all | `fll_login` (`/usr/libexec/fll`) |
| `distro-defaults` | all | build-time generated distro defaults |

---

## Initramfs glue

Built with **dracut**. The `fll` dracut module installs two scripts plus the hooks
needed to produce an initramfs that can boot live media:

| Script | Purpose |
|--------|---------|
| `fll.initramfs` | Mounts the read-only rootfs and sets up the overlay COW layer, persistence, hostname, timezone, and getty |
| `fll.shutdown` | Runs at shutdown via systemd-shutdown |

---

## fll.initramfs

`fll.initramfs` is installed as `/sbin/fll` and run from the dracut initqueue once
per block device candidate. It receives the device path as its first argument,
probes it with `blkid` and performs the following in order:

1. Parses boot parameters from `/proc/cmdline`.
2. Identifies the block device carrying the live media — either an iso9660/carrier
   filesystem (USB stick, optical disc) or a bare rootfs partition exposed by a
   hybrid GPT layout.
3. Optionally copies the rootfs image into a tmpfs (`toram`).
4. Mounts the read-only rootfs (erofs or squashfs).
5. Sets up the overlay — either a volatile tmpfs COW layer (non-persistent) or a
   btrfs `@root` subvolume (persistent, optionally LUKS-encrypted).
6. Bind-mounts the btrfs `@home` subvolume over `/home` when persisting.
7. Writes a udev rule (`/etc/udev/rules.d/70-fll-live.rules`) to create a
   persistent `/dev/fll` symlink (and `/dev/fll-cdrom` for optical drives).
8. Patches Calamares configuration (readonly fstype, initramfs tool, bootloader).
9. Configures hostname, timezone (`/etc/timezone`, `/etc/localtime`, `/etc/adjtime`),
   and the live getty (`getty@.service` override).
10. Creates the `/dev/root` null symlink, which tells dracut that the root is
    mounted, and touches `/run/initramfs/.need_shutdown` so that the initramfs is
    unpacked again for shutdown.

---

## fll.shutdown

`fll.shutdown` is installed as a systemd-shutdown drop-in
(`/usr/lib/systemd/system-shutdown/fll`). When the system shuts down or reboots,
systemd pivots back into the initramfs and runs all scripts in that directory.

If `/dev/fll-cdrom` exists (i.e. the live media was optical and `noeject` was not
used, and the system is not a virtual machine), `fll.shutdown` calls `eject` and
waits for the user to remove the disc before continuing.

---

## Boot parameters (cheatcodes)

All parameters are read from the kernel command line (`/proc/cmdline`). Parameters
are of the form `key=value` or bare words.

### Media location

| Parameter | Description |
|-----------|-------------|
| `iso_uuid=UUID` | UUID of the iso9660 carrier filesystem. Used to identify the correct block device when multiple removable devices are present. Typically set by the bootloader. |
| `rootfs_uuid=UUID` | UUID of the rootfs partition itself (e.g. an erofs partition exposed directly by a hybrid GPT image). When this is set the script skips the iso9660 container and mounts the partition directly. |
| `fromiso=PATH` | Path to an ISO file on a filesystem. The file is loop-mounted as an iso9660 volume and the rootfs image is read from within it. |
| `fromhd=DEV` | Restrict probing to a specific block device. Accepts `UUID=<uuid>`, `/dev/disk/by-uuid/<uuid>`, or a `/dev/*` path. Set automatically by **grub2-fll-fromiso**. |
| `image_dir=DIR` | Override the directory inside the carrier filesystem that contains the rootfs image file. Defaults to the value from `/etc/default/distro`. |
| `image_file=FILE` | Override the rootfs image filename. Defaults to the value from `/etc/default/distro`. |

### Persistence

| Parameter | Description |
|-----------|-------------|
| `persist_uuid=UUID` | UUID of a btrfs partition to use for persistent storage. The `@root` subvolume is used as the overlay upper directory; `@home` is bind-mounted over `/home`. Both `persist_uuid` and `rootfs_uuid` must be given together. |
| `persist_luks_uuid=UUID` | UUID of a LUKS container wrapping the persist btrfs partition. When set, the passphrase is requested via Plymouth (with up to 3 attempts) or read from `/dev/console`. The unlocked device appears as `/dev/mapper/fll-persist`. |

### Locale and identity

| Parameter | Description |
|-----------|-------------|
| `hostname=NAME` | Set a custom hostname in `/etc/hostname`, `/etc/mailname`, and `/etc/hosts`. |
| `tz=TIMEZONE` | Set the timezone. Must match a path under `/usr/share/zoneinfo/`. Both `/etc/timezone` and `/etc/localtime` are written. If omitted, defaults to `Etc/UTC` and Calamares is configured to perform a GeoIP timezone lookup. |
| `utc=yes` | Write `/etc/adjtime` with `UTC` mode (hardware clock is UTC). |
| `utc` or `gmt` | Alias for `tz=Etc/UTC`. |
| `username=NAME` | Override the live username written to `/etc/default/distro`. |

### Debugging

| Parameter | Description |
|-----------|-------------|
| `fll.debug` or `fll=debug` | Enable `set -x` shell tracing in `fll.initramfs`. The trace goes to the console and the journal (`journalctl -b -u dracut-initqueue.service` in the booted system). The environment is also dumped at startup. |

---

## dracut module

Files installed under `dracut/` are placed by the package into `/usr/lib/`:

```
dracut/
├── dracut.conf.d/10-fll.conf        → /usr/lib/dracut/dracut.conf.d/10-fll.conf
└── modules.d/70fll/
    ├── module-setup.sh              → /usr/lib/dracut/modules.d/70fll/module-setup.sh
    ├── 99-fll.rules                 → /usr/lib/dracut/modules.d/70fll/99-fll.rules
    ├── fll-finished.sh              → /usr/lib/dracut/modules.d/70fll/fll-finished.sh
    └── fll-emergency.sh             → /usr/lib/dracut/modules.d/70fll/fll-emergency.sh
```

**`10-fll.conf`** sets dracut to non-hostonly mode (generic initramfs) and includes
the `fll` module.

**`module-setup.sh`** is the dracut module descriptor. Its functions:

- `check()` — refuses to install in hostonly mode (live-only module).
- `depends()` — declares dependencies on the `base`, `fs-lib` and `initqueue`
  dracut modules.
- `installkernel()` — adds kernel modules: iso9660, erofs, loop, squashfs, overlay,
  common filesystems (ext4, btrfs, jfs, f2fs, xfs, ntfs, vfat, exfat, udf),
  pmem modules (of_pmem, nd_pmem, nfit), and dm-crypt.
- `install()` — copies required userspace binaries, the udev rule and the hooks,
  and installs `fll.initramfs` as `/sbin/fll` and `fll.shutdown` as
  `/usr/lib/systemd/system-shutdown/fll`.

**`99-fll.rules`** queues `/sbin/fll <device>` in the dracut initqueue for every
block disk or partition that is added or changed. The job runs once udev has
settled, and again if the device changes later.

**`fll-finished.sh`** is the initqueue finished hook. The initqueue runs the
queued jobs until `/dev/root` exists, or until `rd.retry` seconds (default 180)
have passed.

**`fll-emergency.sh`** prints a warning in the emergency shell when the live
media was not found.

---

## Installed file layout

```
/usr/share/fll-live-initramfs/
├── fll.initramfs          # main live mount script
└── fll.shutdown           # systemd-shutdown eject script

/usr/lib/dracut/
├── dracut.conf.d/10-fll.conf
└── modules.d/70fll/
    ├── module-setup.sh
    ├── 99-fll.rules
    ├── fll-finished.sh
    └── fll-emergency.sh
```

---

## License

GPLv2. See `debian/copyright` for the full list of copyright holders.
