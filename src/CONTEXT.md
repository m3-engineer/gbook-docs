# Project glossary

## mica

The Googlebook's Android device codename (`ro.product.device`, read over adb 2026-10-20).

## bluey

The ChromeOS reference baseboard for Qualcomm X1 devices in coreboot (`src/mainboard/google/bluey`); mica is one
of its variants. Firmware branch `firmware-bluey-16702.B`.

## Hamoa

Qualcomm's platform name for the X1E80100 family; mainline Linux renamed `x1e80100` device-tree files to `hamoa`.

## Tributo

Codename of the Dell XPS 13 9345, the Windows sibling whose mainline device tree
(`x1e80100-dell-xps13-9345.dts`, compatible `dell,xps13-9345`) is the starting point for this one.

## Stock DT

The device tree Googlebook OS boots with: an LZ4-compressed vendor base DTB plus board and keyboard overlays in
the `dtbo_a` partition (`dtb_a` is empty). It is used only as a hardware map ([ADR 0004](docs/adr/0004-device-tree-from-9345.md)).

## Recovery image

Google's public `mica-user/16471258/recovery.zip`: one 19 GB GPT disk image. Build 16471258 is older than the
installed 16560795.

## Stock OS

Googlebook OS (codename Aluminium): Android 17 with a desktop shell, as shipped. Phase 1 reads it without changing it.

## Stock drive and spare drive

The stock drive is the M.2 2230 SSD the laptop shipped with; it stays untouched in a drawer during experiments.
The spare drive is a second 2230 SSD that takes every experiment ([ADR 0002](docs/adr/0002-experiment-on-spare-ssd.md)).

## Gate

The condition that ends a phase. Work from the next phase does not start until its gate passes.
Gate 1 = a proven way back to stock.
Gate 2 = a mainline kernel's own `Linux version` line, captured from the AP console, the panel or the ramoops readback.

## Milestone

A named rung between the gates, M0 to M7 ([ADR 0010](docs/adr/0010-milestones-status-upstream-hold.md)), each with a
"done when" bar. M0 and M1 coincide with Gates 1 and 2, M4 with Gate 3 and M6 with Gate 4. M5 (upstream-ready) ends
the upstream hold. Per-feature state lives in `docs/status.md`.

## Attempt

One boot of one image, with an ID `YYYY-MM-DD-N` and a row in the gitignored `dumps/firstboot/attempts.tsv`
(`scripts/attempt.sh`). Repeat boots of the same image are added to its row.

## Base image and test image

A base image is packaged with no debug command-line or DT extras. A test image has some (for example
`gbook.suspend=1`). `scripts/attempt.sh stick` names which one the stick holds. Only a base image can become a release.

## Release and version

A release is a base image with 3 clean cold boots by `scripts/attempt.sh tally`, which the owner would hand on. Its
version is a CalVer annotated tag `vYYYY.0M.0D[.MICRO]` on the commit that built it
([ADR 0011](docs/adr/0011-versions-and-releases.md)). A version names an image, and an attempt names one boot of it.
`uname -r` carries the gbook commit it was built from, for example `-gbook-g6934235` (`+` for a tree with changes).
A released image keeps that form, and its tag message maps the hash to the version.

## Patch status

The first line of a `kernel/patches/` file: `Status: LOCAL`, `FROMLIST`, `FROMGIT` or `UPSTREAM`, plus a reference
(ChromiumOS's words, with `LOCAL` for its `CHROMIUM`; [ADR 0007](docs/adr/0007-local-kernel-patches.md) update).
Patch numbers are never reused.

## Recovery media

A USB drive (32 GB+) written by Google's Device Recovery Utility Chrome extension; it reinstalls stock OS from the
firmware recovery screen (Esc + F2, then Power, per Google's Googlebook article; Esc + Refresh is the
Chromebook combo).

## Developer mode

ChromeOS firmware state that allows booting non-Google-signed kernels. On mica the recovery screen calls it
"Unlock bootloader" / "Bootloader is unlocked"; it needs OEM unlocking turned on in Android first.

## Kernel partition and FIT

A GPT partition of the ChromeOS-kernel type holding a vboot-signed image. On Arm the payload is a FIT
(Flattened Image Tree): kernel plus one or more device trees, picked by `compatible` (`google,mica-rev*-sku*`).

## ALink

Google's USB bridge cable or dongle that depthcharge's fastboot looks for as USB host; a Prolific PL27A1 also
works. Without one, firmware fastboot runs over TCP via a USB-Ethernet adapter.

## ABL

Qualcomm's Android Bootloader, which loads Android boot images and speaks fastboot. mica does **not** use it
(it boots through depthcharge, found 2026-10-21); kept here because the older plan assumed it.

## RAM boot

`fastboot boot <image>`: boots an image once from memory without writing it to storage. mica's depthcharge
fastboot does not implement it; booting from a USB drive replaces it.

## GSC

Google Security Chip on the board in place of a Windows TPM; on mica it is a **Ti50** (coreboot `TPM_GOOGLE_TI50`). On Chromebooks it provides CCD.

## CCD

Closed Case Debugging: UART consoles for the main processor and the EC over USB-C through the GSC, without
opening the case. mica has it: CCD is Locked, with AP and EC console reads allowed Always (`gsctool -a -I`, 2026-10-21).

## SuzyQ

The USB-C debug cable (here the Fyra Labs SuzyQ Board) that exposes CCD consoles to a second computer. On mica
it works in the left port. the build host sees Ti50 `18d1:5066`, with ttys for the GSC shell, AP (`uart21`), EC and FPMCU.

## EC

Embedded controller: battery, fans, keyboard, lid, Glowbar, LEDs. On mica it is a ChromeOS EC (Zephyr, Nuvoton NPCX9)
over SPI, so mainline `cros_ec` drivers are the starting point; its mica overlay is partly private.

## DTS and DTB

Device tree source and its compiled blob: the hardware description the kernel boots with on Arm.

## GSI and DSU

Generic System Image, an AOSP system image for any Treble device; Dynamic System Updates boots one from new
partitions without touching stock. The cheapest test after unlocking.

## ROOT

The kernel stick's partition 2, GPT name `gbook-root`, 8 GiB from sector 524288, declared by every KERN-A image's
GPT ([ADR 0012](docs/adr/0012-m3-rootfs-debian-sid.md), decision 3). The owner writes `rootfs.ext4` to it; `/init` finds
it as partition 2 of the disk that holds the `kern_guid` partition.

## M3 rootfs

The Debian sid arm64 root filesystem of milestone M3, built by `scripts/build-rootfs.sh` from `rootfs/packages.txt`
with mmdebstrap in the pinned container; `rootfs/customize.sh` adds its units. `gbook-m3` is its capture service
(`GBOOK: m3-<key>=` lines, a second netlog transfer); `gbook-cage` runs Ghostty under cage as user `gbook`.

## mica (ssh host)

the build host's `ssh mica` entry: the booted M3 rootfs at the Wi-Fi lease, key-only, user `gbook` with sudo (ADR 0012 update
2026-11-04). Reads are free; writes need the owner; one connection attempt per boot.
