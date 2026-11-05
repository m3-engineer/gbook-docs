# How Linux can boot on mica's depthcharge firmware

Researched 2026-10-21 from firmware source, Google's docs and a live read of the device. Nothing was changed on the device.

## Answer

The Googlebook boots through **ChromeOS firmware**: coreboot plus the depthcharge bootloader, with Android boot support added on top. Qualcomm ABL is not involved. That changes the plan:

1. **"Unlock bootloader" is ChromeOS developer mode with new labels.** Once unlocked, the firmware boots from external drives and accepts self-signed kernels by default. No `crossystem` step is needed.
2. **The best first-boot route is a ChromeOS kernel partition on a USB drive.** It holds a FIT image (kernel plus device trees), signed with the public developer keys. postmarketOS and depthcharge-tools already boot Qualcomm Chromebooks this way. The stock drive stays untouched.
3. **Firmware fastboot has no `boot` command**, so the planned `fastboot boot` RAM-boot test cannot work. Fastboot is also reachable only through a bridge cable (ALink or Prolific PL27A1) or over TCP via a USB-Ethernet adapter. That explains the "specialized cables" report.
4. **Nobody has a device tree for mica.** Mainline has `hamoa`/`x1e80100` boards, including the XPS 13 9345, but no Chrome-firmware X1 board. Writing that device tree is the core work, as expected.
5. **Closed Case Debugging exists.** GSC consoles are readable while CCD stays locked, so a SuzyQ should give EC (and possibly AP) logs before anything is unlocked.

Items marked *inference* below are reasoned from source, not tested on the device.

## Sources and revisions

| Repo | Ref | Commit |
|---|---|---|
| depthcharge | `firmware-bluey-16702.B` | `694eabf646855067acd51935059c3191436ccc79` |
| depthcharge | main (fastboot check only) | `e91770fa63a431c6a84ff59387a41f7e19222919` |
| vboot_reference | `firmware-bluey-16702.B` | `34fbbe62cc1832016e956d55d72b4aba606b7e21` |
| ChromiumOS coreboot | `firmware-bluey-16702.B` | `ff3258d575b0ddf4ba0514a2cd03c6a1936dba69` |
| ChromiumOS coreboot | main | `80ab88b8322882ce45c18211c21404500d6f689d` |
| ChromiumOS EC | `firmware-bluey-16702.B-main` | `19b76df3d2722a371141bbac61bf14be79f7a44e` |
| ChromiumOS EC (CCD docs) | `cr50_stab` | `ffacd3c99e6a9090a61439d58d46099f0b5ed09e` |
| chromiumos-overlay | `firmware-bluey-16702.B` | `04eaf2635e1fc4533a7ebf32601aa09a4958affb` |
| Linux | torvalds master | `a804c5742bff224d4cb4d25dd383554d598be32b` |
| pmaports / boot-deploy / pmbootstrap | main / 0.25.0 / 3.12.1 | `a683af41…` / `a50452a0…` / `7d23010a…` |
| depthcharge-tools | v0.6.2 | `e62d095bc61a371b69587ba2773e10a5f2e87308` |

> Correction 2026-10-21: `e62d095` is not v0.6.2. It is the `main` head, 107 commits after the tag
> (`git ls-remote` reads `refs/tags/v0.6.2^{}` = `95d17c444ae3a9dec1c51ead6301ed04777314b9`). The citations
> below point at `e62d095`. Found by the FIT packaging research (`docs/research/fit-packaging.md` on branch
> `research/fit-packaging`).

Repos: `https://chromium.googlesource.com/chromiumos/platform/depthcharge`, `…/platform/vboot_reference`,
`…/third_party/coreboot`, `…/platform/ec`, `https://github.com/alpernebbi/depthcharge-tools`,
`https://gitlab.postmarketos.org/postmarketOS/pmaports`. These are branch heads read on 2026-10-21. The exact
commits behind the device's `Google_Mica.16702.59.0/Google_Mica.16702.143.0` build are not public. Local copies
are in `.firecrawl/` (gitignored).

## 1. What mica is

| Fact | Evidence |
|---|---|
| mica is a variant of the **bluey** baseboard | coreboot `src/mainboard/google/bluey/Kconfig.name`: `config BOARD_GOOGLE_MICA` `"->  Mica"`. First upstream commit `a1048f60938f` (CL 90951, merged 2026-01-31) |
| SoC family **Hamoa** = X1E80100 | Kconfig line 140 (16702.B): `select SOC_QUALCOMM_HAMOA`. Linux `8c0b058ab598` renames x1e80100 to hamoa. Live read: soc_id 555, `X1E80100`, 12 CPUs |
| 32 MB AP flash, read over QSPI | `BOARD_ROMSIZE_KB_32768`. Matches Dell's "32 MB flash EPROM" |
| USB-C retimer **PS8820** (the 9345 uses PS8830) | `select MAINBOARD_HAS_PS8820_RETIMER` |
| Camera and fingerprint reader on USB | `MAINBOARD_HAS_CAMERA_VIA_USB`, `MAINBOARD_HAS_FINGERPRINT_VIA_USB` |
| USB-C debug accessory (CCD) port | `HAVE_DEBUG_ACCESS_PORT_SOURCE_SINK`, `DAP_USE_SMB1`. Which physical port is unknown |
| EC: Zephyr on a Nuvoton NPCX9M7FB, partly private | EC `zephyr/program/bluey/BUILD.py`: `register_npcx9_project(project_name="mica", …, extra_modules=["google-private", …])` |
| GSC: **Ti50** | `MAINBOARD_HAS_GOOGLE_TPM` selects `TPM_GOOGLE_TI50`. depthcharge `CONFIG_DRIVER_TPM_GOOGLE_TI50=y` |
| depthcharge board | `configs/config.mica`: `BOARD_DIR="bluey"`, `KERNEL_FIT=y`, `KERNEL_START=0xC7800000`, `KERNEL_SIZE=0x10000000`, `KERNEL_FIT_FDT_ADDR=0xDA800000`, `BOOTCONFIG=y`, `ANDROID_PVMFW=y`, `DRIVER_EC_CROS_SPI=y` |

`config.mica` also sets `DRIVER_SOC_X1P42100=y`. That is the name of the depthcharge SoC driver for the whole
X1 family. coreboot builds mica as Hamoa, and the device reports X1E80100.

Internal disk, live read 2026-10-21 ([recon](../recon/recon-2026-10-21.md)): ChromeOS `KERN-A`, `KERN-B` and
`ROOT-B` sit next to Android A/B partitions: `boot`, `init_boot`, `vendor_boot`, `dtb`, `dtbo`, `vbmeta`,
`pvmfw` and `super`.

## 2. Unlock = developer mode

- **The menu item.** depthcharge `src/vboot/ui/screens.c:765` (16702.B): the Advanced options item
  `.name = "Unlock bootloader"` targets `UI_SCREEN_RECOVERY_TO_DEV` ("Transition to developer mode"). Once
  unlocked, the screen reads "Bootloader is unlocked". Its menu offers Lock bootloader, Boot from internal disk,
  **Boot from external drive** (`:1801`), Select alternate bootloader and Advanced options (which holds
  "Bootloader fastboot").
- **The OEM unlocking toggle.** Android's switch in Developer options maps to the NV bit `VB2_NV_OEM_LOCK`.
  While that bit is set, vboot withholds `DEV_BOOT_ALLOWED` (vboot `firmware/2lib/2misc.c` ~600-613). The
  firmware then shows "Booting with an unlocked bootloader is disabled… enable OEM unlocking in Developer
  options". This matches [Google's steps](https://support.google.com/googlebook/answer/17389679): turn on OEM
  unlocking, then Esc + F2 + Power, then Advanced options > Unlock bootloader.
- **Defaults are already set.** vboot `2misc.c:296-303`: while in normal mode, the firmware presets
  `DEV_BOOT_EXTERNAL=1` and `DEV_ENABLE_FASTBOOT=1`, and clears `DEV_BOOT_SIGNED_ONLY`. That is the trogdor
  `crossystem dev_boot_usb=1 dev_boot_signed_only=0` step, done ahead of time. This matters because Googlebook OS
  has no `crossystem` (live read: not on PATH).
- **Self-signed kernels boot.** `vb2_need_kernel_verification` is false in dev mode unless FWMP or
  `dev_boot_signed_only` says otherwise (`2misc.c` ~821-837). On the ChromeOS path, a keyblock whose signature
  fails is still accepted on its hash (`2load_kernel.c` ~163-253). The body must still match the keyblock's own
  key, so the kernel must be self-signed, not unsigned. The public dev keys (`/usr/share/vboot/devkeys`) work.

## 3. Boot routes after unlocking

### Route A: ChromeOS kernel partition with a FIT image (recommended)

vboot treats a GPT entry as bootable when its type is the ChromeOS kernel GUID `fe3a2a5d-4f32-41a7-b725-accc3285a309`
or the Android vbmeta GUID (`cgptlib_internal.c`, `2load_kernel.c:696-733`). For ChromeOS entries, depthcharge
loads the body to `KERNEL_START` and boots it as a **FIT** (`src/arch/arm/fit.c:57-68`).

FIT image rules (verified in source):
- **Compression:** none, lzma, lz4 or legacy-lz4 only (`src/boot/fit.c:291-311`). The arm64 `Image` magic is
  checked (`boot64.c:188`), so a gzip `Image.gz` fails.
- **Device-tree choice:** depthcharge ranks each FIT configuration's `compatible` against
  `google,mica-rev<board>-sku<sku>`, then `google,mica-rev<board>`, `google,mica-sku<sku>` and `google,mica`
  (`fit.c:49-102`, name from coreboot's `MAINBOARD_PART_NUMBER` "Mica"). With no match it boots
  `/configurations/default`. The ordering is documented in the kernel's
  `Documentation/arch/arm/google/chromebook-boot-flow.rst`.
- **What depthcharge writes into the DT:**
  - `/chosen`: `bootargs`, `kaslr-seed` and `rng-seed`.
  - Memory: replaces every memory node with one `/memory` from coreboot's map and adds `/reserved-memory`
    regions (`dt_update.c`).
  - Ramdisk: `linux,initrd-start/end`.
  - `/firmware/coreboot` (with `board-id`, `sku-id`, `fw-config`), `/firmware/chromeos`, ramoops, LPDDR info and
    the pKVM pvmfw and DRNG reservations.
  - bluey's `cpumap_fixup.c` also marks defective CPU cores `status = "fail"` based on SoC ID.

Tooling: depthcharge-tools `mkdepthcharge` wraps `mkimage` and `vbutil_kernel` and signs with the dev keys. Its
`boards.ini` has no mica entry; a custom section is needed (*inference*: values from `config.mica`):

```ini
[boards/custom/mica]
arch = arm64
codename = custom-mica
dt-compatible = google,mica(-rev\d+)?(-sku\d+)?
image-format = fit
image-start-address = 0xC7800000
image-max-size = 256 MiB
```

> Correction 2026-10-21: this section is incomplete. `[boards/arm64]` in `boards.ini` at `e62d095` (lines
> 3514-3521) sets `boots-lz4-kernel`, `boots-lzma-kernel` and `loads-fit-ramdisk = True`. Per the FIT packaging
> research, a custom board section does not pick these up, so without them `depthchargectl build` patches the
> initramfs into the DTB, pads the kernel and tries only an uncompressed kernel. Add these three lines to the section:
>
> ```ini
> loads-fit-ramdisk = True
> boots-lz4-kernel = True
> boots-lzma-kernel = True
> ```
>
> A plain `dt-compatible = google,mica` is enough: depthcharge-tools extends it to the `-rev`/`-sku` pattern itself.

Disk layout, per the pmbootstrap precedent (`pmb/install/partition.py:105-203`): a ChromeOS-kernel partition
with `cgpt add -t kernel -S 1 -T 5 -P 10`, holding the signed image, plus a root partition. depthcharge-tools
adds `kern_guid=%U`, which the firmware expands to the partition's PARTUUID, so `root=PARTUUID=%U/PARTNROFF=1`
finds the next partition.

### Route B: modified Android GKI boot image

vboot's Android path (`2load_android_kernel.c:320-468`) verifies `boot`, `init_boot`, `vendor_boot`, `pvmfw` and
`dtbo` with AVB. In dev mode, verification errors are allowed and the boot state turns `orange`. The DT comes from
the `dtbo` partition's table (`android_dtboimg.c`). The kernel command line comes only from `vendor_boot`.
*Inference:* if no dtbo base entry matches, depthcharge falls back to a FIT inside the boot image. This route
overwrites stock partitions, so it ranks below Route A.

### Route C: alternate firmware payload (RW_LEGACY)

coreboot's `chromeos.fmd` has an `RW_LEGACY` region outside write-protected RO. depthcharge runs payloads listed
in `altfw/list` when `DEV_BOOT_ALTFW` is allowed (`payload.c`, `screens.c:2041-2063`). This is how a UEFI
payload (EDK2 or U-Boot) could boot generic distro images. It needs `flashrom` with root to write `RW_LEGACY`,
plus an arm64 Hamoa payload that nobody has built. This is a later option, not the first boot.

## 4. Firmware fastboot

- **Commands** (`src/fastboot/cmd.c`, 16702.B): `continue`, `upload`, `download`, `erase`, `flash`, `getvar`,
  `oem cmdline|bootconfig add/del/set`, `oem logs`, `oem read/write-ufs-descriptor`, `oem set-successful`,
  `oem set-priority`, `oem sha256`, `reboot[-…]`, `set_active` and `snapshot-update`. main adds only `fetch`.
  There is **no `boot`, no `flashing unlock` and no `oem unlock`.**
- **Transport** (`fastboot.c:241-261`, `usb.c:16-28`): depthcharge is the USB *host*. It looks for a
  Prolific PL27A1 (`067b:27a7`) or a Google ALink cable or dongle (`18d1:506d/506e/506f/5084`), then falls back to
  TCP port 5554 over DHCP with ASIX, r8152 or smsc95xx USB-Ethernet adapters. bluey registers no USB device-mode
  controller, so a plain USB-C cable to a PC cannot reach it.
- **Present in production?** It is linked in only with `CONFIG_FASTBOOT_IN_PROD`, which the depthcharge ebuild
  sets when `use avb`. *Inference (strong):* mica needs AVB for Android boot, so fastboot is present. The board
  overlay is private.
- **Use here:** `flash` with no allow-list and `oem set-priority`/`set-successful` can install and select a
  kernel partition, given a USB-Ethernet adapter on a DHCP network. That makes it an optional install path, not a
  RAM boot. Android's userspace `fastbootd` (`reboot-fastboot`) is separate.

## 5. Closed Case Debugging

Live read 2026-10-21 (`gsctool -a -I` runs as the adb shell user): CCD **Locked**, no password. The Always
capabilities are:
- `UartGscRxAPTx` (read the AP console)
- `UartGscRxECTx` (read the EC console)
- `UartGscRxFpmcuTx`
- `FlashRead`
- `UnlockNoReboot` and `UnlockNoShortPP`

`FlashAP`, `FlashEC`, `OverrideWP` and `OpenNoDevMode` are `IfOpened`, and `AllowUnverifiedRo` is `Never`. GSC
firmware: RO 2.0.119, RW 0.33.291.

From `docs/case_closed_debugging_gsc.md` (EC `cr50_stab`):
- **Consoles:** the doc says Ti50 enumerates as `18d1:504a`. On mica it is `18d1:5066`, and Linux exposes the consoles as ttys ([ccd-gsc.md](ccd-gsc.md)), so `usb_console` is not needed. `usb_console -d 18d1:504a -i 1` gives the AP console and `-i 2`
  the EC console.
- **Opening CCD:** needs developer mode, then `gsctool -a -o` and repeated power-button presses over about
  5 minutes. Opening wipes dev mode.
- **Flashing over CCD:** `flashrom -p raiden_debug_spi:target=AP` works once CCD is open (`FlashAP`).
- **Caveat:** "the AP console itself is disabled for production devices". So the AP UART may carry nothing, even
  though the capability allows it.

`FlashRead` is not a flash dump. The same doc's capability table says it allows "dumping a hash of the AP or EC
flash". A full AP flash backup over `raiden_debug_spi` still needs CCD opened, and opening needs developer mode.

*Inference:* with the Fyra SuzyQ on the debug-accessory port, the EC console (and maybe firmware logs) can be
read **now, with no unlock**. A flash *hash* could also be taken now, to compare against later.

## 6. Recovery image (Gate 1)

`https://dl.google.com/device/recovery/mica-user/16471258/recovery.zip` answered HEAD with 200, 7,601,764,157
bytes, Last-Modified 2026-10-05 15:44 GMT [11:44 EDT] (found via cros.tech/googlebook/mica, not downloaded).
Saving it covers the log's "save a copy of the recovery image" item, with one problem: its build number
**16471258 is older than the installed build 16560795** (fingerprint `…/CL3B.260622.276.R2/16560795`). Anti-rollback
may refuse it. Before relying on it for Gate 1, check the build inside the zip and whether the Device Recovery
Utility serves a newer image than this static URL. It should also contain the stock `dtb`,
`dtbo` and `vendor_boot` images, which means the **vendor device tree and firmware without unlocking** (*inference:
check the zip's layout*).

## 7. Proposed path

Status 2026-10-21: step 1 is done. The recovery zip is extracted ([stock-dtb.md](stock-dtb.md)) and the EC and GSC consoles were read ([ccd-gsc.md](ccd-gsc.md)). The DTS for step 3 is drafted (`dts/`). Recorded as [ADR 0003](../adr/0003-first-boot-chromeos-kernel-partition.md).

1. **Before unlock:** save the recovery zip (check the build-number question in section 6) and extract the stock
   DTB, dtbo and firmware. Read the EC console
   (and the AP console, if live) with the SuzyQ.
2. **Unlock** (owner, after Gate 1): OEM unlocking, Esc + F2 + Power, Unlock bootloader.
3. **First boot (Route A):**
   - Build a mainline kernel with a `google,mica` DTS: start from `x1e80100-dell-xps13-9345.dts` and use the
     stock DTB as the hardware map.
   - Package it with `mkdepthcharge` and dev keys onto a USB drive's ChromeOS-kernel partition.
   - Choose Boot from external drive.
4. **Console:** CCD AP/EC UART if live. Otherwise ramoops (depthcharge always reserves it) read back on the next
   stock boot, or the panel through `mdss` once the DTS is good enough.

## Not found

- Any `mica` or `bluey` device tree (mainline, `chromeos-6.12`, the 16702.B kernel branch, lore linux-arm-msm).
- Public board overlays for bluey or mica (to confirm `use avb`), and the exact firmware build commits.
- ~~Which physical USB-C port is the debug-accessory port~~: the left one works (tested 2026-10-21); the right is untested.
- Any public report of Linux or another non-Android OS running on a Googlebook. AskUbuntu 1570130 (2026-10-07)
  is unanswered.
- Board-id and sku-id values (still unknown): `/proc/device-tree` reads are denied to adb shell. They are in `/firmware/coreboot`
  once booted, or in the stock DTB.
