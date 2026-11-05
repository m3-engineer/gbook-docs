# 3. First boot through a ChromeOS kernel partition on external storage

## Status

Accepted 2026-10-21. Supersedes the log's original Phase 2 plan (`fastboot boot` of an Android boot image, then
Mu-Silicium as a fallback).

## Context

The original plan assumed Qualcomm ABL and Android fastboot. Recon and source research showed otherwise
([recon](../recon/recon-2026-10-21.md), [chromeos-boot-path.md](../research/chromeos-boot-path.md)):

- The bootloader is ChromeOS **depthcharge** (`Google_Mica.16702.*`, branch `firmware-bluey-16702.B`).
- Google's "Unlock bootloader" is vboot **developer mode**. After the transition, the firmware enables external
  boot and fastboot, and it boots self-signed kernels.
- depthcharge's fastboot has **no `boot` command**, so there is no RAM boot. It runs only through an ALink or
  PL27A1 bridge, or over TCP via a USB-Ethernet adapter.
- vboot accepts ChromeOS-type kernel partitions (FIT image: kernel plus DTBs) and Android vbmeta partitions.
  depthcharge picks a FIT configuration by `compatible`, down to `google,mica`.

## Decision

The first Linux boot uses a **ChromeOS kernel partition** (GUID `fe3a2a5d-…`) on a USB drive or the spare SSD:

- **Image:** a FIT image with the mainline `Image`, the mica DTB and an initramfs, signed with the public vboot
  developer keys.
- **Build:** depthcharge-tools with a `[boards/custom/mica]` section.
- **Boot:** from the "Boot from external drive" menu.

The Android GKI route (modified `boot`/`vendor_boot`/`dtbo`) and RW_LEGACY alternate firmware are fallbacks, not
the plan.

## Consequences

- The stock SSD and its Android partitions are never written during first-boot tests.
- No special cable is needed. The SuzyQ on the left port gives the AP console ([ADR 0006](0006-debug-console-ccd-suzyq.md)).
- Partition attributes (priority, tries, successful) decide what boots. A bad image falls back to the next
  partition or the menu, not to a brick.
- postmarketOS's trogdor recipe (`deviceinfo_generate_depthcharge_image`, cgpt) applies almost directly.
- Still to confirm on the device: the board-id/sku-id DT match, and whether depthcharge leaves a framebuffer.

## Update 2026-10-21

Source research answered both items under "Still to confirm on the device", pending a live boot:
- **DT match:** not a blocker. A DTB whose root compatible holds `google,mica` matches any board-id and sku-id, and a
  single-DTB FIT keeps a default config that boots even without a match. depthcharge prints the real ids on the AP
  console ([fit-packaging.md](../research/fit-packaging.md)).
- **Framebuffer:** depthcharge adds no `simple-framebuffer` node. coreboot's scan-out at `0xE4800000` stays live, and
  mainline can use it through `COREBOOT_FRAMEBUFFER` and simpledrm only if the DTS reserves that region `no-map`
  ([silent-boot-observation.md](../research/silent-boot-observation.md)).
- **Exception level:** the kernel starts at EL2 with no hypervisor, so the DTB needs the `x1-el2.dtso` changes
  ([el2-handoff.md](../research/el2-handoff.md)).

## Update 2026-10-21 (first-boot details)

Decided on the first-boot map:
- **Image:** a 256 MiB image holding only KERN-A (128 MiB), `cgpt add -i 1 -t kernel -S 0 -T 3 -P 15`. It is rewritten
  whole for every attempt, which resets vboot's tries (Iteration loop).
- **Hookup:** a dedicated USB stick in the right USB-C port, on battery, with the SuzyQ on the left. The owner writes
  the stick with `pkexec dd` (Boot media and port hookup).
- **Firmware fastboot over TCP is ruled out:** it writes only the single fixed disk, the stock SSD (depthcharge
  `694eabf` `src/fastboot/disk.c:40-44`).
- **DTB:** the FIT carries `x1e80100-google-mica-el2.dtb`, because the kernel enters at EL2 with no hypervisor
  (EL2 handoff).

## Update 2026-11-05 (12:20 PM EST): the stock drive locked read-only from `/init`

"The stock drive is never written" is now enforced mechanically for the Linux side of a boot: `/init`'s `lock_stock()`
(task #36, after the Steam Frame initramfs's `blockdev_ro` hook, re-implemented from its description in
[steamos-arm.md](../research/steamos-arm.md)) runs right after the stick is identified by its `kern_guid` partition and sets
every other block device, whole disks and partitions, read-only at the block layer (`blockdev --setro`); ram, loop, zram
and dm devices are skipped, and an unknown GUID locks nothing (locking the stick blindly would break ROOT). The capture
`GBOOK: lock-ro=` names what was locked, `none: only the stick (sda)` while the NVMe driver stays `# forbid-y`, or
`skipped:` with the reason. It is advisory against mistakes: a root process can `--setrw`. `check.sh` 58 drives it on a
synthetic `/sys/class/block` with a fake `blockdev`. Untested on the device until the next boot.

