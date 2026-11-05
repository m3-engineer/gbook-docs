# How mica boots Linux

The Dell XPS Googlebook does not boot like other Snapdragon X laptops. There is no Qualcomm ABL (Android Bootloader) and
no UEFI: the machine runs ChromeOS firmware, and Linux gets in through the door that firmware already has for
self-signed kernels (boot-path note, "Answer" and "Route C"). Sources: [the boot-path
note](docs/research/chromeos-boot-path.md), [the FIT packaging note](docs/research/fit-packaging.md), [the EL2 handoff
note](docs/research/el2-handoff.md), [ADR 0001](docs/adr/0001-recovery-gates-unlock.md) and [ADR
0003](docs/adr/0003-first-boot-chromeos-kernel-partition.md).

## The firmware stack

The firmware is coreboot plus the depthcharge bootloader, with Android boot support added on top; vboot (verified boot)
sets the rules depthcharge enforces about what may run (boot-path note, "Answer"). The firmware build carries no
hypervisor image at all, no Gunyah and no QHEE (EL2 handoff note, "1. Firmware chain", also the table's source).

| Stage | Exception level | Role |
|---|---|---|
| coreboot | EL3 | board init; loads BL31 and the secure OS |
| BL31 (Trusted Firmware) | EL3 | starts the payload at EL2 |
| QTEE (Qualcomm's trusted execution environment) | secure EL1 | secure OS |
| depthcharge | EL2 | picks and verifies the kernel |
| Linux | EL2 | entered with a plain branch, no `eret` |

## Developer mode is the "unlock"

Google's "Unlock bootloader" menu item is ChromeOS developer mode under a new label, and Android's "OEM unlocking"
switch is the vboot flag that withholds developer boot until it is on. The Chromebook USB-boot settings are preset: in
normal mode the firmware turns external boot on and signed-only boot off (boot-path note, "2. Unlock = developer mode").

"Self-signed" is precise: developer mode takes the keyblock on its hash, but the kernel body must still verify against
the keyblock's own key, so the image is signed with a self-consistent key pair, by convention the public vboot developer
keys (boot-path note, "2. Unlock = developer mode"; FIT packaging note, "4. Dev keys").

## The recovery gates come first

Unlocking wipes the device, and nobody had shown that Google's recovery media restores an unlocked unit or relocks the
bootloader. So no unlock happens until Gate 1 passes: recovery media made and booted to the recovery screen, the key
combination recorded, the recovery image and build saved, the fingerprint and bootloader version recorded, and the data
the next phase needs backed up. The owner does those steps by hand; agents never unlock, flash or enter recovery (ADR
0001, "Context" and "Decision"). On 2026-11-02 Gate 1 passed: Device Recovery Utility media reached the recovery screen
and served the installed build. The public recovery zip alone had not passed it, because its build 16471258 is older
than the installed 16560795 and anti-rollback might refuse it (ADR 0001, "Update 2026-10-21" and "Update 2026-11-02").

## The route: a FIT image on a ChromeOS kernel partition

vboot treats a GPT entry as bootable when its type is the ChromeOS kernel GUID `fe3a2a5d-4f32-41a7-b725-accc3285a309`;
depthcharge loads the body into its kernel buffer and boots it as a FIT, U-Boot's Flattened Image Tree (boot-path note,
"Route A"). ADR 0003 chose that route on a USB stick: the stock SSD is never written during boot tests, and a bad image
falls back to the next partition or the menu, not a brick (ADR 0003, "Decision", "Consequences").

The partition holds a vboot kernel blob: a 64 KiB vblock followed by a FIT with one kernel, one device tree blob (DTB)
and one ramdisk. `mkdepthcharge` from depthcharge-tools builds and signs it in one command, wrapping `mkimage` and
`vbutil_kernel` with the developer keys (FIT packaging note, "Answer" and "1. mkdepthcharge for a custom board"). The
firmware's rules (same note, "2. Compression and the 256 MiB limit"):

| Constraint | Rule |
|---|---|
| Kernel format | plain arm64 `Image`; depthcharge checks the arm64 magic, so `Image.gz` fails |
| Compression | none, lz4 or lzma only; the FDT and ramdisk nodes must be `none` |
| Size | the packed body must fit the firmware's 256 MiB kernel buffer; the decompressed kernel goes elsewhere |

The first-boot image is 256 MiB and holds a 128 MiB `KERN-A`, rewritten whole for every attempt; since milestone M3 the
rootfs is partition 2 of the same stick, from 256 MiB on (ADR 0003, "Update 2026-10-21 (first-boot details)"; [ADR
0012](docs/adr/0012-m3-rootfs-debian-sid.md), decision 3).

**Configuration matching.** depthcharge prefers `google,mica-rev<board>-sku<sku>` down to a plain `google,mica`, ranks
each FIT configuration by its best match, and boots `/configurations/default` when nothing matches (boot-path note,
"Route A"). A DTB whose root compatible holds `google,mica` matches any board-id and sku-id, and the default is a safety
net and a trap, since a wrong DTB still boots (FIT packaging note, "Answer", step 6). On 2026-11-02 the coreboot table
reported `board-id` 3 and no `sku-id` ([first boot](docs/recon/firstboot-2026-11-02.md), "Result").

**Partition attributes.** vboot keeps priority, tries and successful bits in each entry's GPT attributes: it picks the
highest priority above zero and spends a try on each boot of an entry whose successful bit is clear (FIT packaging note,
"5. Partition type and attributes"). The project writes `cgpt add -t kernel -S 0 -T 3 -P 15`, three tries then fall
back. pmbootstrap's `-S 1 -T 5 -P 10` is for an installed system: with `successful` already set, tries are ignored and a
kernel that panics is picked again on every boot (same note, "Answer", step 5).

## Entering at EL2

depthcharge jumps to the kernel with a plain branch, no `eret`, so Linux starts at EL2 with no hypervisor underneath
(EL2 handoff note, "Answer"). On 2026-11-02 the first boot logged `CPU: All CPU(s) started at EL2` (first boot,
"Result").

Mainline's `hamoa.dtsi` assumes Gunyah owns some hardware, so the FIT carries `x1e80100-google-mica-el2.dtb`: the mica
DTS with the kernel's `x1-el2.dtso` overlay applied. The overlay enables the Qualcomm APSS watchdog and the PCIe SMMU
(the system IOMMU), maps the PCIe controllers onto that SMMU, disables the generic SBSA watchdog, the GPU zap shader and
the IRIS video block, and adds `iommus` to the ADSP and CDSP remote processors (ADR 0003, "Update 2026-10-21 (first-boot
details)"; EL2 handoff note, "2. What x1-el2.dtso changes"). Overlays cannot delete properties, so mica's differences
live in [the fixups file](dts/mica-el2.fixups): it removes those remoteproc `iommus` again, because the stock mica tree
has none, and with them the PAS (peripheral authentication service) driver asks TrustZone for a resource table that
mica's TrustZone refuses with `-EIO`, leaving the ADSP offline (attempt 2026-11-02-4; fixups header; [dts
README](dts/README.md), "EL2 overlay" row).

## The command line and the console

`mkdepthcharge` prepends `kern_guid=%U` to the stored command line; at boot depthcharge replaces `%U` with the kernel
partition's PARTUUID in lowercase, appends `cros_secure` and writes the result into `/chosen/bootargs`. The rest is
`console=ttyMSM0,115200n8 earlycon=qcom_geni,0x894000`; the UART address was spelled out because the draft DTS then
lacked `/chosen/stdout-path`, which a bare `earlycon` needs; the DTS gained it on 2026-10-21 (FIT packaging note, "3.
Kernel command line"; dts README, "Console" row).

The console is read through Closed Case Debugging (CCD): with the Google Security Chip (GSC) still locked, a SuzyQ cable
exposes the AP (application processor) and EC (embedded controller) consoles, read-only here, though Google's
documentation warns that the AP console is disabled on production devices ([ADR
0006](docs/adr/0006-debug-console-ccd-suzyq.md), "Context" and "Decision"; boot-path note, "5. Closed Case Debugging").
On 2026-11-02 the AP console carried kernel output only from 0.67 s on, once `ttyMSM0` probed; the full log came from
ramoops, read back on the next stock boot (first boot, "Channels").

## What the initramfs does

The FIT's ramdisk holds `/init`, which finds the block device whose `PARTUUID` equals `kern_guid`, takes that device's
parent disk, and requires the disk's partition 2 to carry the label `gbook-root`. It mounts that partition on
`/newroot`, moves `/dev`, `/proc` and `/sys` over, and runs `switch_root` into the Debian rootfs; without it, or on a
failed mount, it falls back to capture-and-reboot (ADR 0012, decision 4; [the M3 rootfs
note](docs/research/m3-rootfs.md), "4.2"). The rootfs path has worked on the device since the 2026-11-04 attempts
([status](docs/status.md), "Rootfs from USB").

Since 2026-11-05 `/init` also enforces "the stock drive is never written": right after the stick is identified, it sets
every other block device read-only at the block layer with `blockdev --setro`; an unknown GUID locks nothing. It is
advisory (root can undo it) and was untested on the device when recorded (ADR 0003, "Update 2026-11-05").

## What this page does not cover

The Nura postmarketOS port installs through `pmbootstrap` and is the way to get a packaged system today: [Dell XPS
Googlebook (google-mica)](https://wiki.nura.eco/wiki/Dell_XPS_Googlebook_(google-mica)). There is no image to download
from this site: the recipes are documented in the notes above, and the public repository holds no binaries.
