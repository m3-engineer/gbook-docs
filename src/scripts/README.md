# Build scripts

The header of each build script in the private repository, as of this build. The scripts themselves run on the
project's build host and are not published yet (their paths and listeners are specific to it).

## `setup-toolchain.sh`

```
Set up the DTS toolchain outside the repo (idempotent): a sparse torvalds/linux checkout at the pinned commit
(DTS sources, bindings, every Kconfig file and the arm64 defconfig), a dtschema venv, and the processed binding schema.
  scripts/setup-toolchain.sh            -> $GBOOK_TOOLS (default ~/.cache/gbook)
  PYTHON=python3.14 scripts/setup-toolchain.sh   (the macOS host: bare python3 is 3.15 there)
  GBOOK_FULL=1 scripts/setup-toolchain.sh        (the build host: the whole tree, for scripts/build-kernel.sh; ~1.5 GB)
Then: scripts/build-dtb.sh ~/.cache/gbook/linux-<short> dts/x1e80100-google-mica.dts /tmp/mica.dtb
      ~/.cache/gbook/venv-dtschema/bin/dt-validate -s ~/.cache/gbook/schema-<short>.json /tmp/mica.dtb
The commit is the one the mica DTS was forked from (ADR 0004); change both together.
```

## `build-dtb.sh`

```
Compile a board DTS against a mainline kernel tree the way Kbuild does (cpp, then dtc), without building a kernel.
  scripts/build-dtb.sh <kernel-tree> <file.dts> [out.dtb] [extra.dtsi ...] [overlay.dtso ...] [fixes.fixups ...]
A .dtsi is a diagnostic built on top of the board DTS (a wrapper #includes the DTS, then each .dtsi in order), so an
experiment from dts/diag/ never edits the stock-traceable DTS (retro 2026-11-03; GBOOK_DTS_EXTRA in package-image.sh).
With overlays, out.dtb is the base with each overlay applied by fdtoverlay, as Kbuild builds "-dtbs" targets
(scripts/Makefile.dtbs), e.g. the first-boot DTB:
  scripts/build-dtb.sh <tree> dts/x1e80100-google-mica.dts /tmp/mica-el2.dtb <tree>/arch/arm64/boot/dts/qcom/x1-el2.dtso \
    dts/mica-el2.fixups
A .fixups file lists "delete-property <label> <property>" lines (labels from /__symbols__), applied with fdtput
after the overlays, because overlays cannot delete properties.
The kernel tree only needs arch/arm64/boot/dts/qcom, include/dt-bindings and scripts/dtc/include-prefixes
(a sparse checkout is enough). The DTS may live outside the tree: its own directory is searched first.
Preprocesses with $CC -E like Kbuild (Apple's cpp wrapper misparses -o). Prints dtc warnings; exits non-zero on any error.
```

## `build-kernel.sh`

```
Build the mica kernel Image on the build host: arm64 defconfig at the pinned commit + every kernel/*.config fragment
(mica-firstboot.config first, then the rest in name order),
clang/lld (LLVM=1), out of tree. Image only: no modules, no in-tree dtbs (scripts/build-dtb.sh builds the DTB).
  GBOOK_FULL=1 scripts/setup-toolchain.sh     # once: the full kernel tree
  scripts/build-kernel.sh [kernel-tree] [out-dir]
Defaults: $GBOOK_TOOLS/linux-a804c57 and $GBOOK_TOOLS/build-a804c57 (GBOOK_TOOLS defaults to ~/.cache/gbook).
Applies kernel/patches/*.patch first (ADR 0007; the kernel release then ends in -dirty).
Writes <out-dir>/localversion-gbook (gbook_localversion below), so the release names the gbook commit too: it reads
like 7.3.0-gbook-g6934235-ga804c5742bff-dirty (a release keeps that form: ADR 0011 maps the hash to its tag).
Fails if any CONFIG_ line or "# require:" symbol of any fragment is not =y after the merge (ticket 06), or if any
"# forbid-y:" symbol is =y (safety rails, e.g. the NVMe driver near the stock SSD).
Needs clang, ld.lld, make, flex, bison, bc, perl and openssl headers.
```

## `package-image.sh`

```
Package the first-boot image on the build host: stage Image, the -el2 DTB and /init, then run scripts/package-in-container.sh
in the digest-pinned Debian sid container through pkexec (the owner stays out of the docker group, ticket 06).
  scripts/build-kernel.sh && scripts/package-image.sh
Output: $GBOOK_TOOLS/out/{mica-usb.img,mica.kpart,manifest.txt,...} (GBOOK_TOOLS defaults to ~/.cache/gbook).
Firmware: scripts/stage-firmware.sh rebuilds $GBOOK_TOOLS/firmware (stock modem_a + the build host's linux-firmware, never in
git: ADR 0005) and checks it against kernel/firmware.sha256; the tree goes into the initramfs at /lib/firmware.
Wi-Fi: ~/.local/state/gbook/wifi.conf (owner-written wpa_supplicant network block), if present, goes in as
/etc/wpa_supplicant.conf.
Writes nothing to a USB drive; the owner does that with pkexec dd (ticket 13).
```

## `build-rootfs.sh`

```
Build the M3 rootfs (ADR 0012; .scratch/m3-rootfs ticket 03): Debian sid arm64 from one snapshot.debian.org
timestamp, mmdebstrap in the digest-pinned container of scripts/package-image.sh, run rootless with podman
(retro-8/05). Output in $GBOOK_TOOLS/rootfs (GBOOK_TOOLS defaults to ~/.cache/gbook), never in git:
  out/rootfs.ext4     the ROOT image (GBOOK_ROOTFS_SIZE, default 4G; label gbook-root), from out/rootfs.tar
  out/lock.txt        every installed package as pkg:arch=version, sorted (the lock list)
  out/manifest.txt    snapshot, SOURCE_DATE_EPOCH, container digest, tool versions, counts and sha256s
  out/mmdebstrap.log  the build log; cache/ keeps every .deb (snapshot answered 503/504 on 2026-11-04)
  scripts/build-rootfs.sh [YYYYMMDDTHHMMSSZ]      (default: today 00:00 UTC; ticket 02 sized 20261104T000000Z)
  GBOOK_ROOTFS_MIRROR=http://deb.debian.org/debian   while snapshot.debian.org is down: the manifest then says snapshot=none
                                                     and requested_snapshot=<ts>, so release tooling (ticket 12) sees it
  GBOOK_ROOTFS_OFFLINE=1   rebuild from cache/ alone, pinned to the previous out/lock.txt (no network for packages)
The manifest's lock_changed= line counts lock.txt lines that differ from the previous build's (kept as lock.prev.txt).
Mode (ADR 0012, decision 9): the container runs mmdebstrap inside its own user namespace (unshare --map-root-user
--map-auto, the substance of mmdebstrap's unshare mode; as container root mmdebstrap would skip the namespace and
fail to mount, 2026-11-04). GBOOK_ROOTFS_MODE=sysadmin instead adds SYS_ADMIN to the rootless container and runs
mmdebstrap's root mode directly: a capability inside podman's user namespace, not on the host.
Writes nothing to a USB drive; the owner writes ROOT (ticket 11).
```

## `stage-firmware.sh`

```
Rebuild the initramfs firmware tree $GBOOK_TOOLS/firmware (default ~/.cache/gbook/firmware) from its two sources,
and check every file against kernel/firmware.sha256 (hashes only in git; the blobs never are: ADR 0005).
  scripts/stage-firmware.sh                 stage and check; fails on any hash change or missing file
  scripts/stage-firmware.sh --update        stage and rewrite kernel/firmware.sha256 (after a deliberate change)
  scripts/stage-firmware.sh board2 [regex]  list board-2.bin entry names matching regex (e.g. 'subsystem-vendor=105b')
Sources:
  stock  = the recovery-stick copy's modem_a partition (dumps/gate1/), read with scripts/fat_ls.py, no mount
  distro = the build host's linux-firmware-atheros and wireless-regdb packages (/usr/lib/firmware), zstd-decompressed
  pkg    = files from an Arch package the build host does not install (linux-firmware-qcom: the Adreno X1-85 GPU firmware and
           the Dell XPS 13 9345 audio topology),
           downloaded once into $GBOOK_TOOLS/pkgs, signature-checked against pacman's keyring, extracted, never
           installed. The version matches the distro linux-firmware packages (20260916-1).
package-image.sh copies the staged tree into the initramfs at /lib/firmware.
```

## `mkpatch.sh`

```
Assemble a local kernel patch (ADR 0007) from the edited kernel tree, then restore the tree (retro-15/02: three
revisions of patch 0010 were 40-line heredocs each, and a prose "Status:" line failed check 34 once).
  scripts/mkpatch.sh <NNNN-slug> --subject '<text>' --notes <file> [--body <file>] [--status '<WORD> <reference>']
                     [--assisted-by <id>] [--tree <dir>] [--out <file>]
Edit the files in the tree first (its HEAD is the pin). The patch is the tree's diff of its modified tracked files:
  line 1   Status: <status>, checked <today>        default: LOCAL gbook (ours; not sent: upstream hold until M5)
  prose    the notes file: why, evidence, what it changes (gbook's block before the mail header)
  mail     From 0000…, From: the gbook repo's git identity, Date: now (date -R), Subject: [PATCH] <subject>,
           the body file (or the subject alone), Assisted-by: <id> (default Claude), ---, diffstat, diff
Then the touched files go back to HEAD, so the tree stays what build-kernel.sh expects (it applies every patch itself).
--out names the file (default kernel/patches/<NNNN-slug>.patch; a new number takes the next unused one, check 34).
```

## `release-draft.sh`

```
Draft a release's annotated tag message (ADR 0011 and its 2026-11-04 update; .scratch/m3-rootfs ticket 12). Checks the
release bar first, prints the message, writes it to $GBOOK_TOOLS/out/tag-<version>.txt and names the owner's git tag
command. Tags nothing: the owner tags (CLAUDE.md, "Git").
  scripts/release-draft.sh <milestone> <attempt id regex> [vYYYY.0M.0D[.MICRO]]   (default version: today's date)
The bar (ADR 0011): one base image, 3 clean cold boots. "clean" is scripts/attempt.sh tally's SCMI verdict over the
rows the regex selects (anchor it: '^2026-11-04-12$'); "cold" is each row's start column (boot_start.py, the row's first
boot); "base image" is what attempt.sh stick last read back from the stick. The rootfs must be pinned by date
(manifest snapshot=, not none: a GBOOK_ROOTFS_MIRROR build is not release material).
The rootfs on the stick's partition 2 must be that manifest's (attempt.sh root-verify's record, retro-9/01).
check.sh 46 runs the two checks alone: release-draft.sh --self-check <tally line> <starts> <stick file> <manifest> [<root file>].
```

