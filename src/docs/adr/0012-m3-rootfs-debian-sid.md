# 12. M3 rootfs: Debian sid from a snapshot, on the stick's partition 2, entered by switch_root

## Status

Accepted 2026-11-04 (owner: "yes" to the ten open questions of [m3-rootfs.md](../research/m3-rootfs.md), section 5).
Nothing in it has run on mica yet; section 4 of the note is inference until the first rootfs boot.

## Context

- M3 ([ADR 0010](0010-milestones-status-upstream-hold.md)) needs a rootfs from USB with Mesa on the GPU and Wi-Fi in
  userspace, a known audio state, and the first release tag ([ADR 0011](0011-versions-and-releases.md)).
- Mesa does not separate the candidates: X1-85 support landed in Mesa 24.2 (MR !30249, merged 2024-07-18), and every
  candidate ships 26.x. Ghostty 1.4 arm64 exists only in Omarchy's aarch64 repo (research note, sections 1-2).
- The packaging already runs in a digest-pinned Debian sid container, and Debian can be pinned to one
  snapshot.debian.org timestamp. Omarchy aarch64 has no dated pin, and its install path is UEFI-only.
- Everything the kernel needs is built in, and `uname -r` changes with every gbook commit (ADR 0011).

## Decision

1. **Debian sid arm64**, built by `mmdebstrap` in the pinned container from one snapshot.debian.org timestamp, with a
   lock list and a local `.deb` cache. Omarchy aarch64 (Arch Linux ARM base) is revisited at M4.
2. **Ghostty 1.4.0 is built from its signed source tarball** (Zig, as Omarchy's PKGBUILD does). If that fails, M3 goes
   without Ghostty until M4.
3. **ROOT is partition 2 of the same stick**, from 256 MiB on. Every image's GPT declares it, so the per-attempt
   256 MiB `dd`, `verify` and `gpt` stay as they are. The owner writes ROOT only when the rootfs changes.
4. **`/init` finds ROOT next to the booted kernel partition**: the partition whose `PARTUUID` equals `kern_guid`, its
   disk's partition 2, which must be labelled `gbook-root`. It mounts it, then `switch_root`s. No ROOT, or a failed
   mount, runs today's capture-and-reboot path. The command line does not change.
5. **The Wi-Fi network block and the stock ADSP/CDSP firmware stay in the initramfs.** `/init` copies them to the
   new root's `/run/gbook/` before the hand-off. The rootfs image carries no secret, no vendor blob and no identifier
   ([ADR 0005](0005-vendor-content-out-of-git.md)).
6. **Every driver stays built in.** New needs get `kernel/*.config` fragments. The rootfs ships no `/lib/modules`.
   `kernel/mica-rootfs.config` turns `FW_LOADER_USER_HELPER` off, as systemd's README asks.
7. **Audio gets one test attempt:** the 9345's sound node as a `dts/diag/` overlay (unverified per
   [ADR 0004](0004-device-tree-from-9345.md)), a `kernel/mica-audio.config`, and Debian's 9345 topology and UCM.
   Either outcome is the "known state".
8. **No getty on the AP console, no `sshd`, nothing listening.** The panel runs Ghostty under `cage` as an
   unprivileged user.
9. **The container build tries mmdebstrap's unshare or fakechroot mode first**, and `--cap-add SYS_ADMIN` only if
   those fail.
10. **A release names both images.** See the ADR 0011 update of the same date.

## Consequences

- The rootfs keeps the netlog format and listener: one shared sender script serves `/init` and the rootfs. A base
  rootfs sends after its checks and then stays up.
- The first rootfs boot must check two assumptions: that firmware lookups after `switch_root` resolve against the new
  root, and that the GPU's first open there finds `gen70500_*`. If either fails, the stock files or the command line
  change, and this ADR gets an update.
- `wpa_supplicant@wlan0` needs a drop-in to read `/run/gbook/`.
- The work is tracked in `.scratch/m3-rootfs/`.

## Update 2026-11-04 (3:08 PM ET): how decision 9 came out

`scripts/build-rootfs.sh` runs the pinned container rootless with podman (retro-8/05), not through `pkexec docker`.
Inside it, mmdebstrap's own unshare mode does not apply: as container root it skips the user namespace, and container
root cannot mount without `SYS_ADMIN` (probe, 2026-11-04). The script makes the same namespace by hand (`unshare
--map-root-user --map-auto --mount --pid --fork`, a subuid range for root) and runs mmdebstrap's root mode inside it;
podman's `--security-opt unmask=ALL` lets that namespace mount `/proc` ("Mount too revealing" otherwise). The arm64
essential set built this way in 32 s under qemu binfmt. fakechroot was not tried: mmdebstrap(1) says the mode fails with
a different libc inside the chroot than outside, which a foreign-architecture chroot is. `GBOOK_ROOTFS_MODE=sysadmin`
keeps the third option (`--cap-add SYS_ADMIN`, a capability inside podman's user namespace only, never on the host).

## Update 2026-11-04 (3:52 PM ET): the reproducibility contract, and throttling

From [rootfs-pinning.md](../research/rootfs-pinning.md) (recommendations 1, 4 and 7), after the first builds of
ticket 03:
- **Two builds of one snapshot timestamp must agree on `lock.txt` and the `rootfs.tar` sha256.** The `rootfs.ext4`
  sha256 is expected to agree only between builds with the same e2fsprogs version, which the manifest records: the
  container installs its tools from live sid at build time. The first two builds agreed on all three.
- **The answer to snapshot.debian.org's throttling is the `.deb` cache plus an offline flat repository**
  (`GBOOK_ROOTFS_OFFLINE=1`, pinned to the previous `lock.txt`), not a mirror switch: Debian publishes no limit figures,
  `snapshot-cloudflare.debian.org` fronts the same backend (live headers, *inference*), and no third-party snapshot
  mirror resolved on 2026-11-04. A build on another mirror (`GBOOK_ROOTFS_MIRROR`) says `snapshot=none` in its manifest
  and is not release material (ADR 0011).

## Update 2026-11-04 (6:38 PM ET): decisions 5 and 8 change, sshd for the build host

Owner ("yes" to the ranked options after the second ROOT boot; rootfs-access.md,
recommendations 1 and 2). The rootfs runs `sshd`, key-only, for the build host alone (`AllowUsers gbook@<the build host's LAN address>`,
`PermitRootLogin no`, no passwords), and `gbook` has `sudo` for the agent's reads and unit restarts; writes on the
device still need the owner's word, as everywhere. The image stays free of keys: the host key and the build host's authorized
key travel in the initramfs (`~/.local/state/gbook/ssh`, packaged like the Wi-Fi block) and `/init` copies them to
`/run/gbook/`; `ssh.service` has `ConditionPathExists` on the host key, Debian's baked host keys are removed from the
image, and `sshd-keygen` is masked (an empty machine-id is no first boot, so it would never run, and must not write
keys to ROOT). The AP console stays read-only (ADR 0006); the gettys stay masked. The boot journal also travels as a
section of the rootfs's netlog, so a Wi-Fi failure still leaves the journal on the stick and a working boot sends it.
