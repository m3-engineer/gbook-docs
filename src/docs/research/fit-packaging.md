# Packaging and signing a mica FIT, and checking it offline

Researched 2026-10-21 on the build host from upstream source at pinned commits, distro package metadata and a read of the stock
`dtbo` table in `dumps/` (read only). The Googlebook was not touched. Nothing was installed. Items marked *inference*
are reasoned from source, not tested.

Ticket: `03-fit-packaging`. Decision context:
[ADR 0003](../adr/0003-first-boot-chromeos-kernel-partition.md), [chromeos-boot-path.md](chromeos-boot-path.md).

## Answer

A mica kernel partition is a vboot kernel blob (64 KiB vblock + body) whose body is a FIT with one kernel, one DTB and
one ramdisk. `mkdepthcharge` builds it in one command. Everything except the actual boot can be checked on the build host.

**Step list**

1. **Tools.** Run the toolchain in a Debian sid container (all four packages are official there), or install
   `extra/uboot-tools` plus AUR `vboot-utils` and run depthcharge-tools from a git checkout (see
   [8](#8-installing-the-tools-on-arch)). Docker is active on the build host, but `the owner` is not in the `docker` group (live
   read 2026-10-21), so the container runs through `pkexec`:

   ```sh
   pkexec docker run --rm -it -v /home/the owner/.cache/gbook/out:/out debian:sid bash
   # inside:
   apt-get update && apt-get install -y depthcharge-tools vboot-kernel-utils vboot-utils cgpt u-boot-tools device-tree-compiler
   sha256sum /usr/share/vboot/devkeys/{kernel.keyblock,kernel_data_key.vbprivk,kernel_subkey.vbpubk}
   ```

   The three hashes must equal the pinned `tests/devkeys` values in [4](#4-dev-keys).

2. **Inputs.**
   - `Image`: the plain arm64 `Image`, not `Image.gz`. depthcharge checks the arm64 magic `0x644d5241` after its own
     decompression step and knows only none/lz4/lzma.
   - `mica.dtb`: from `scripts/build-dtb.sh`. Its root `compatible` must contain the exact string `google,mica`. The
     current draft does: `google,mica qcom,x1e80100` (live read of the built DTB, 2026-10-21).
   - `initramfs.cpio.gz`: any cpio the kernel can unpack. Gzip inside the cpio is fine. FIT-level ramdisk compression
     must be `none`, and mkimage writes none.

3. **Build and sign** (keys default to `/usr/share/vboot/devkeys`):

   ```sh
   mkdepthcharge -o /out/mica.kpart --tmpdir /out/mkdc-tmp -v \
     -A arm64 --format fit -C none \
     -c "console=ttyMSM0,115200n8 earlycon=qcom_geni,0x894000 ignore_loglevel" \
     -d /out/Image -i /out/initramfs.cpio.gz -b /out/mica.dtb
   ```

   - mkdepthcharge prepends `kern_guid=%U`, so the stored cmdline is
     `kern_guid=%U console=ttyMSM0,115200n8 earlycon=qcom_geni,0x894000 ignore_loglevel`.
   - At boot depthcharge replaces `%U` with the kernel partition's PARTUUID (lowercase) and appends ` cros_secure`.
     It also appends `cpufreq.default_governor=powersave`, but only when booting with no battery.
   - It runs `mkimage -f auto -A arm64 -T kernel -O linux -C none -n … -i initramfs -b mica.dtb -d Image`, then
     `fdtput … type kernel_noload`, then `vbutil_kernel --version 1 --arch aarch64 --vmlinuz depthcharge.fit --config
     kernel.args --bootloader empty.bin --keyblock … --signprivate … --pack`, then `vbutil_kernel --verify`.
   - `--tmpdir` keeps `depthcharge.fit` for the checks below.
   - Leave out `root=` for the first boot. The initramfs is the whole userspace.
   - `--kernel-start` is not needed. On arm64 it only feeds the 32-bit initramfs hacks, which stay off.

4. **Offline checks** (all on the build host, no device):

   ```sh
   fdtget mica.dtb / compatible                      # contains google,mica
   dumpimage -l mkdc-tmp/depthcharge.fit             # kernel-1, fdt-1, ramdisk-1, conf-1
   fdtget mkdc-tmp/depthcharge.fit /configurations default        # conf-1 (one DTB keeps the default)
   fdtget mkdc-tmp/depthcharge.fit /images/fdt-1 compression      # none
   fdtget mkdc-tmp/depthcharge.fit /images/kernel-1 compression   # none | lz4 | lzma
   fdtget mkdc-tmp/depthcharge.fit /images/kernel-1 data-size     # must FAIL: data is embedded, not external
   vbutil_kernel --verify mica.kpart --signpubkey /usr/share/vboot/devkeys/kernel_subkey.vbpubk --verbose
   vbutil_kernel --verify mica.kpart                 # hash-only path, same as dev-mode firmware
   futility show mica.kpart
   stat -c %s mica.kpart                             # body must be <= 0x10000000 (256 MiB)
   ```

   Expected `--verify` output: keyblock flags `23` (0x17), "Body verification succeeded", and a Config that echoes the
   cmdline with a literal `%U`.

5. **Disk** (build as a file on the build host, then copy it to the USB drive as an owner step):

   ```sh
   truncate -s 2G mica-usb.img
   cgpt create mica-usb.img
   cgpt boot -p mica-usb.img                         # protective MBR, for Linux later
   cgpt add -i 1 -t kernel -b 8192 -s 262144 -l KERN-A -S 0 -T 3 -P 15 mica-usb.img   # 128 MiB
   cgpt add -i 2 -t data -b 270336 -s 3923935 -l ROOT mica-usb.img   # optional rootfs for later; fits the 2 GiB file
   dd if=mica.kpart of=mica-usb.img bs=512 seek=8192 conv=notrunc
   cgpt show mica-usb.img
   cgpt show -i 1 -P mica-usb.img; cgpt show -i 1 -T mica-usb.img; cgpt show -i 1 -S mica-usb.img
   ```

   - `-t kernel` gives type `fe3a2a5d-4f32-41a7-b725-accc3285a309`.
   - `-S 0 -T 3 -P 15` means "try three times, then fall back". vboot spends a try on each attempt while
     `successful` is 0.
   - pmbootstrap's `-S 1 -T 5 -P 10` is for an installed system. With `successful=1` the tries count is ignored, so a
     kernel that panics is picked again on every boot.
   - Sizes are in device blocks. The numbers above assume 512-byte sectors.

6. **FIT matching is not a blocker.** depthcharge prefers `google,mica-rev<R>-sku<S>`, then `google,mica-rev<R>`,
   `google,mica-sku<S>` and `google,mica`. A DTB whose root compatible holds `google,mica` matches whatever board-id
   and sku-id the EC reports. With one DTB, mkdepthcharge also keeps `default = "conf-1"`, which boots even with no
   match. That is a safety net, and a trap: a wrong DTB still boots.

**What cannot be checked offline:**
- depthcharge's own config choice. There is no upstream unit test for `fit.c` at 694eabf; the logic is small enough
  to check by reading.
- The real board-id and sku-id.
- Whether depthcharge's DT fixups (`dt_apply_fixups`) succeed on a mainline-shaped DT.
- Whether earlycon prints anything.

On the AP console, depthcharge prints `Compat preference: …` and `Choosing best match …` (`fit.c:384-387, 439-440`),
which reveals board-id and sku-id on the first boot.

**Follow-ups for other files (not edited here):**
- [chromeos-boot-path.md](chromeos-boot-path.md) labels `e62d095` as depthcharge-tools v0.6.2. It is
  `v0.6.2-107-ge62d095` (2026-10-19); the tag is `95d17c4` (2023-06-30).
- Its draft `[boards/custom/mica]` section lacks `loads-fit-ramdisk`, `boots-lz4-kernel` and `boots-lzma-kernel`.
  See [1](#1-mkdepthcharge-for-a-custom-board).
- The draft DTS has no `/chosen/stdout-path` (`fdtget` → `FDT_ERR_NOTFOUND`, 2026-10-21), so a bare `earlycon` would
  do nothing. Hence the explicit `earlycon=qcom_geni,0x894000` above.

> Update 2026-10-21: all three follow-ups are applied on main in commit `709212e`: dated corrections in
> `chromeos-boot-path.md`, and `/chosen/stdout-path` in the DTS.

## Sources and revisions

| Repo | Ref | Commit |
|---|---|---|
| depthcharge | `firmware-bluey-16702.B` | `694eabf646855067acd51935059c3191436ccc79` |
| vboot_reference | `firmware-bluey-16702.B` | `34fbbe62cc1832016e956d55d72b4aba606b7e21` |
| ChromiumOS coreboot | `firmware-bluey-16702.B` | `ff3258d575b0ddf4ba0514a2cd03c6a1936dba69` |
| depthcharge-tools | master (`v0.6.2-107`) | `e62d095bc61a371b69587ba2773e10a5f2e87308` (tag v0.6.2 = `95d17c444ae3a9dec1c51ead6301ed04777314b9`) |
| pmaports | master | `a683af41125794aeeba199cd53928332df4e6256` |
| pmbootstrap | 3.12.1 | `7d23010a125ca7386fec4e390d14128b6c24d266` |
| boot-deploy | master | `a50452a054233c2d7bf6142cbc332c94c79cc18f` |
| U-Boot (`tools/fit_image.c`) | tag `v2026.07` (Arch `uboot-tools` 2026.07-2) | tag |
| Linux | torvalds master | `a804c5742bff224d4cb4d25dd383554d598be32b` |

All read 2026-10-21. Paths below are relative to each repo. Line numbers refer to these commits.

## 1. mkdepthcharge for a custom board

**mkdepthcharge is board-agnostic.** It takes the arch, format, compression, cmdline, keys and files
(`depthcharge_tools/mkdepthcharge.py:597-978`). For `fit` it runs:
- `mkimage -f auto -A <arch> -T kernel -O linux -C <compress> -n <name> [-i initramfs] -b <dtb>… -d <vmlinuz>`
  (`:1190-1202`);
- `fdtput <fit> <kernel node> type kernel_noload` (`:1214-1219`);
- `fdtput -d /configurations default`, only when there is more than one DTB (`:1221-1227`);
- `vbutil_kernel --version <n> --arch <vboot arch> --vmlinuz <fit> --config <cmdline file> --bootloader
  <512-byte empty file> --keyblock … --signprivate … --pack <out>` (`:1240-1250`), then `vbutil_kernel --verify`
  (`:1401-1410`).

For arm64 the vboot arch string is `aarch64` (`utils/platform.py:536-545`), which futility maps to `ARCH_ARM`
(vboot `futility/cmd_vbutil_kernel.c:290-291`). `--kernel-start` is used only by the `--patch-dtbs` and
`--pad-vmlinuz` hacks (`mkdepthcharge.py:1059-1188`). The manual says arm64 depthcharge decompresses the kernel to a
safe place itself, so the hacks are for 32-bit boards (`mkdepthcharge.rst:151-169`).

**The board section only matters for `depthchargectl build`/`check`.** boards.ini tells users to add "fully specified
sections with a unique codename" (`depthcharge_tools/boards.ini:7-29`). Sections inherit only from their `/`-separated
parents (`utils/collections.py:11-42`). So `[boards/custom/mica]` inherits nothing from `[boards/arm64]`
(`boards.ini:3514-3521`, which sets `boots-lz4-kernel`, `boots-lzma-kernel` and `loads-fit-ramdisk`).

Those keys default to False (`depthchargectl/__init__.py:123-137`). With `loads-fit-ramdisk` False, `depthchargectl
build` turns on `patch_dtbs` (`_build.py:549`). That adds `/chosen/linux,initrd-*` to the DTB and pads the kernel.
Without the two `boots-*` keys, only `none` compression is tried (`_build.py:434-442`).

A complete section:

```ini
[depthchargectl]
board = custom-mica

[boards/custom/mica]
arch = arm64
codename = custom-mica
name = Dell XPS Googlebook (mica, custom)
dt-compatible = google,mica
image-format = fit
image-max-size = 256 MiB
image-start-address = 0xC7800000
loads-fit-ramdisk = True
boots-lz4-kernel = True
boots-lzma-kernel = True
```

- A plain `dt-compatible = google,mica` is extended to `google,mica(-rev\d+)?(-sku\d+)?` automatically
  (`utils/string.py:112-131`). It is used only to pick DTBs from an fdtdir (`_build.py:238-292`).
- `image-start-address` is informational on arm64 (see above).
- `image-max-size` makes `depthchargectl build` reject a too-large image (`_build.py:589`).

**Version differences.** e62d095 is 107 commits past the v0.6.2 tag. For a one-DTB FIT build, the relevant code is
the same in both, apart from the new `default` removal for multi-DTB FITs (`git diff v0.6.2 e62d095 --
depthcharge_tools/mkdepthcharge.py`).

**Precedent.**
- pmaports trogdor: `deviceinfo_depthcharge_board="qc7180"`, `deviceinfo_depthcharge_compression="lzma"`, a 128 MiB
  kpart at sector 8192 (`device/community/device-google-trogdor/deviceinfo:21-34`).
- boot-deploy runs `depthchargectl build --root none --board … --kernel … --kernel-cmdline … --initramfs … --fdtdir …
  --compress … --output …` (`boot-deploy-functions.sh:1078-1108`).

## 2. Compression and the 256 MiB limit

**Allowed formats.**
- depthcharge reads a FIT image node's `compression` as none, lzma or lz4. Anything else is invalid
  (`src/boot/fit.c:140-165`), and decompression supports exactly those (`:291-311`).
- mkdepthcharge offers `none`, `lz4` and `lzma` and passes `-C none` explicitly, because mkimage otherwise assumes
  gzip (`mkdepthcharge.py:685-699, 993-1003`).
- The FDT image node must be `none` when the config has no `compatible` (`fit.c:254-259`), and mkimage writes `none`
  for every `-b` file (U-Boot `tools/fit_image.c:392-393`).
- The FIT ramdisk must be `none` (`fit.c:484-488`); a ramdisk node with no `compression` property counts as none
  (`fit.c:143`).

**Embedded data only.** depthcharge reads only the `data` property (`fit.c:149-151`). A FIT built with external data
(`mkimage -E`) would load empty images. `mkimage -f auto` embeds the data (`fit_image.c:368`).

**Kernel placement.**
- depthcharge partly decompresses the kernel to read the arm64 header, checks magic `0x644d5241` (`boot64.c:44,
  178-192`) and takes `image_size` from it (`:194-197`).
- It picks a KASLR slot outside `[min(BASE_ADDRESS, KERNEL_START, FIT_FDT_ADDR), 4 GiB)` (`boot64.c:129-133`) and
  decompresses or copies the kernel there (`:199-210`).
- So the decompressed kernel never has to fit the 256 MiB buffer. Only the packed body does.

**The 256 MiB limit.**
- `config.mica` sets `CONFIG_KERNEL_START=0xC7800000` and `CONFIG_KERNEL_SIZE=0x10000000`.
- The linker script turns those into `_kernel_start`/`_kernel_end` (`src/image/depthcharge.ldscript.S:38-39`), and
  vboot gets `kernel_buffer_size = _kernel_end - _kernel_start` (`src/vboot/stages.c:162-163`).
- vboot rejects a body larger than the buffer ("Kernel body doesn't fit in memory", vboot
  `firmware/2lib/2load_kernel.c:389-392`). It requires the body to start within the first 64 KiB of the partition
  (`:378-382`; futility's default `--pad` is 65536, `cmd_vbutil_kernel.c:33`).
- The body is `roundup(FIT, 4K) + 4 KiB cmdline + 4 KiB params + roundup(bootloader, 4K)`
  (`futility/vb1_helper.c:668-685`, sizes in `futility/kernel_blob.h:15-21`). So the FIT may be up to about
  256 MiB − 12 KiB.
- The partition must hold 64 KiB + body.

**The DT limit.** The flattened DT after depthcharge's edits must fit the 8 MiB FDT buffer at `0xDA800000`
(`depthcharge.ldscript.S:40-41`, `src/arch/arm/fit.c:105-111`). The draft DTB is 215,695 bytes.

**Ramdisk placement.** The ramdisk stays inside the FIT in the kernel buffer, below 4 GiB, as `fit_add_ramdisk`
assumes (`fit.c:335-348`).

**Choice.**
- *Inference:* use `-C none` for the first boot. It has the fewest moving parts, and an arm64 Image plus a small
  initramfs is far below 256 MiB.
- `lz4` is the fallback if USB read time or partition size matters. lzma is the slowest to decompress in firmware.
- depthchargectl itself tries none, then lz4, then lzma, and keeps the first that fits (`_build.py:434-442,
  562-597`).

## 3. Kernel command line

- **Storage.** mkdepthcharge writes the cmdline to a file for `vbutil_kernel --config`. An empty cmdline becomes `--`,
  because vbutil_kernel rejects an empty one (`mkdepthcharge.py:876-881`). The config slot is 4096 bytes including
  the NUL (`kernel_blob.h:15`, `vb1_helper.c:73-75`).
- **`kern_guid=%U`.** mkdepthcharge prepends it unless `--no-kern-guid` is given (`mkdepthcharge.py:885-905`,
  `mkdepthcharge.rst:236-249`).
- **`%U` expansion.**
  - vboot copies the chosen entry's unique GUID into `params->partition_guid` (`2load_kernel.c:761-762`).
  - depthcharge passes it to `commandline_subst` (`src/vboot/stages.c:307-312`), which replaces each `%U` with the
    GUID in lowercase (`src/boot/commandline.c:79-85`).
  - It then appends every queued parameter with a leading space (`:94-98`):
    - `cros_secure` on the ChromeOS path (`src/vboot/boot_info.c:56`);
    - `cpufreq.default_governor=powersave` only when `board_boot_in_no_battery_mode()` (`src/board/bluey/board.c:161-163`).
  - The result goes into `/chosen/bootargs` (`src/boot/dt_update.c:38`). The working buffer is 2 × 4096 bytes
    (`stages.c:293`, `src/vboot/boot_info.h:43`).
- **`root=PARTUUID=%U/PARTNROFF=1`.** The kernel resolves this form itself (`block/early-lookup.c:41-61, 226-246` at
  a804c57). It matters only when the kernel mounts root, that is with no initramfs `/init`.
  - *Inference:* an initramfs's own init would have to parse `PARTNROFF` itself.
  - For the first boot, leave `root=` out. Keep `kern_guid=%U`: pmOS's boot-deploy uses it to find the partition to
    write the next image to (`boot-deploy-functions.sh:1121-1144`).
- **Console.**
  - uart21 is `serial@894000` (`arch/arm64/boot/dts/qcom/hamoa.dtsi:1296-1298` at a804c57). The draft DTS sets
    `compatible = "qcom,geni-debug-uart"` on it and `serial0 = &uart21`.
  - The GENI driver registers earlycon `qcom_geni` for that compatible and names its ttys `ttyMSM`
    (`drivers/tty/serial/qcom_geni_serial.c:1755, 1769, 1785`).
  - `earlycon=qcom_geni,<addr>` "must already be setup and configured" (`Documentation/admin-guide/
    kernel-parameters.txt:1515-1519`). Bare `earlycon` uses `/chosen/stdout-path` (`:1398-1403`), which the draft
    DTS lacks.
  - So: `console=ttyMSM0,115200n8 earlycon=qcom_geni,0x894000`.
  - *Inference:* if the firmware leaves uart21's clocks off, earlycon stays silent while `ttyMSM0` still works once
    the driver probes. The kernel needs `CONFIG_SERIAL_QCOM_GENI_CONSOLE=y`.

## 4. Dev keys

- **What vboot checks in developer mode.**
  - `need_keyblock_valid` is false (`2load_kernel.c:143`; [chromeos-boot-path.md](chromeos-boot-path.md) section 2).
  - When the keyblock signature fails against mica's kernel subkey, vboot accepts the keyblock on its SHA-512 hash
    (`:164-181`).
  - Keyblock flag mismatches only clear `keyblock_valid` (`:184-211`).
  - The body must still verify against the keyblock's own data key (`:433-438`).
  - So any self-consistent key pair boots. The public dev keys are the convention.
- **Where they come from.** vboot_reference ships them in `tests/devkeys/`. `make install` copies them to
  `/usr/share/vboot/devkeys` (`Makefile:30, 448-453`). At 34fbbe6, sha256:

  | File | sha256 |
  |---|---|
  | `kernel.keyblock` | `ca2feab9d94eae768fea8616e52cda6cb5576b3d45cd8f7f8af0ce14cb9ce252` |
  | `kernel_data_key.vbprivk` | `bc9e707a86e55a93f423e7bcdae4a25fd470b868e53829b91bbe2ccfbc6da27b` |
  | `kernel_subkey.vbpubk` | `36b9c5fa6f5d0432b9acbe8e2b7da2e602162a87a425575c6d7ba975a0440708` |

  - `kernel.keyblock` decodes to header 2.1, size 1208 bytes and flags `0x17` = DEVELOPER_0 | DEVELOPER_1 |
    RECOVERY_0 | MINIOS_0 (offsets from `firmware/2lib/include/2struct.h:371-418`, read on the build host 2026-10-21). That
    matches `KERNEL_KEYBLOCK_MODE` (`scripts/keygeneration/common.sh:87`) and passes in dev mode without recovery
    and without miniOS.
  - `key.versions` says kernel key version 1 and kernel version 1. mkdepthcharge's default `--tpm-kernel-version` is
    1 (`mkdepthcharge.py:966-978`). Rollback checks do not apply when `need_keyblock_valid` is false
    (`2load_kernel.c:313-323`).
- **On the build host.** mkdepthcharge searches, in order:
  - `--keydir`, or the directories of any given key;
  - `/etc/depthcharge-tools`;
  - `/usr/share/vboot/devkeys`;
  - `/usr/local/share/vboot/devkeys` (`utils/platform.py:166-198`, `mkdepthcharge.rst:257-268`).

  Sources:
  - AUR `vboot-utils` copies `tests/devkeys` to `/usr/share/vboot/devkeys` (its PKGBUILD `package()`).
  - Debian's `vboot-kernel-utils` ships the same file names there (packages.debian.org sid file list, read
    2026-10-21).
  - With no install at all, `--keydir <vboot_reference checkout>/tests/devkeys` works.

  Check any copy against the table above.

## 5. Partition type and attributes

- **Type.** vboot boots GPT entries whose type is the ChromeOS kernel GUID `fe3a2a5d-4f32-41a7-b725-accc3285a309` or
  the Android vbmeta GUID (`firmware/include/gpt.h:46-47`, `firmware/lib/cgptlib/cgptlib_internal.c:157-170`). cgpt's
  alias for the first is `kernel` (`cgpt/cgpt_common.c:653`); `data` is Linux data (`:656`).
- **Attribute bits.** Priority sits in bits 48-51, tries in 52-55 and successful in 56
  (`cgptlib_internal.h:40-53`). `cgpt add -S/-T/-P` set them (`cgpt/cmd_add.c:16-33`). `cgpt show -i N
  -S|-T|-P|-A` reads them back (`cgpt/cmd_show.c:19-41`).
- **Selection.**
  - `GptNextKernelEntry` skips entries with neither `successful` nor `tries`, and picks the highest priority > 0
    (`firmware/lib/cgptlib/cgptlib.c:44-120`).
  - A booted entry with `successful=0` gets a try deducted (`2load_kernel.c:768-779`). With `successful=1`, tries are
    ignored (`cgptlib.c:135-144`).
  - A failing entry is marked bad and the next one is tried (`2load_kernel.c:742-743`).
- **Precedent.** pmbootstrap uses `cgpt add -i <kernel> -t kernel -b <start> -s <size> -l pmOS_kernel -S 1 -T 5 -P 10`,
  then an `efi` boot partition and a `data` root (`pmb/install/partition.py:107-204`). It writes the image with `dd`
  (`pmb/install/_install.py:651-663`).
- **First-boot recommendation.** Use `-S 0 -T 3 -P 15` instead (*inference* from the selection code). That matches
  ADR 0003's "a bad image falls back". depthchargectl's `bless --oneshot` sets `successful=0`, `tries=1` and the
  highest priority (`depthchargectl.rst:247-252`).
- **Stock disk, for contrast** ([stock-dtb.md](stock-dtb.md)). The stock `boot_a` has the ChromeOS-kernel type but
  holds a plain Android boot image (magic `ANDROID!` at offset 0, read 2026-10-21) and has priority 0. So vboot's
  ChromeOS path never picks it, and the Android path goes through `vbmeta`.

## 6. FIT configuration matching, and what the stock dtbo table says

**The match list.**
- depthcharge builds the compatibles from coreboot's mainboard part string, lowercased with `_` → `-`
  (`src/boot/fit.c:49-102`). For mica that string is `"Mica"` (coreboot `src/mainboard/google/bluey/Kconfig:317-325`
  at ff3258d).
- The list is `google,mica-rev<board_id>-sku<sku_id>`, `google,mica-rev<board_id>`, `google,mica-sku<sku_id>` and
  `google,mica`. Entries whose id is undefined are skipped (`fit.c:80-101`).
- Nothing in the bluey board code adds compatibles: `fit_add_compat` is called only from `fit.c`.
- The ordering is documented in `Documentation/arch/arm/google/chromebook-boot-flow.rst:21-49`.

**How a config is ranked.**
- Each FIT config is ranked by the best (lowest-index) list entry that equals any of its compatible strings
  (`fit.c:228-289`; exact string match). The best-ranked config wins; with no match, `/configurations/default` boots
  (`fit.c:436-449`).
- `mkimage -f auto` writes `conf-N { kernel, fdt, loadables, ramdisk }` with no `compatible`
  (`fit_image.c:482-531`).
- So depthcharge takes the "legacy FIT" branch and reads the first `compatible` property of the DTB's root node. That
  requires an uncompressed FDT and no overlays (`fit.c:248-274`).
- The draft DTB's root `compatible = "google,mica", "qcom,x1e80100"` therefore matches rank 3 on any board-id and
  sku-id.

**Where board-id and sku-id come from.**
- mica selects `MAINBOARD_HAS_CHROME_EC` (bluey Kconfig:79-92), which selects `EC_GOOGLE_CHROMEEC` (`:282-287`).
- So coreboot reads board_id from the EC board version and sku_id from the EC's SKU (`bluey/boardid.c:21-24,
  41-42`).
- The values are not public. depthcharge prints them on the AP console (`fit.c:384-387`) and writes them to
  `/firmware/coreboot` in the booted DT ([chromeos-boot-path.md](chromeos-boot-path.md) section 3).

**Stock dtbo table** (`dumps/recovery-16471258/parts/dtbo_a.img`, header and entries decoded 2026-10-21; version 1,
3 entries of 32 bytes). depthcharge parses v1 entries as `dt_size, dt_offset, id, rev, flags, custom[3]`
(`src/boot/android_dt_table.h:43-53`). It treats `rev` as `min_rev = rev & 0xffff`, `max_rev = rev >> 16`; `0..0xffff`
means "any" (`android_dtboimg.c:82-92`). `custom[0] & 0xff == 0` makes `custom[1]` a SKU, where `0xffffffff` means
any (`:139-145, 228-229, 259-263`). Compression is `flags & 0xf` (`android_dt_table.h:35-41`).

| Entry | id | rev | min..max board_id | flags | SKU (`custom[1]`) | Meaning |
|---|---|---|---|---|---|---|
| 0 base | 0 | `0xffff0000` | 0..0xffff (any, no rev check) | 3 = LZ4 | `0xffffffff` (any) | every board |
| 1 board overlay | 0 | `0xffff0000` | any | 3 = LZ4 | any | every board |
| 2 keyboard overlay | 0 | `0x000f0001` | **1..15** | 3 = LZ4 | any | board_id 1-15 only |

- `id` is unused (0) and only echoed as an index. The table does not encode a SKU at all.
- The only board-id information is that the keyboard-matrix overlay applies to board revisions 1-15.
- *Inference:* production mica reports a board_id between 1 and 15, and rev 0 (early proto) boards had a different
  keyboard. The real value stays unknown until the first boot.
- The mainline DTB does not depend on it, as shown above. A rev- or sku-specific DTB can be added later with
  `google,mica-rev<N>` compatibles.

## 7. What can be verified offline

| Check | Command | Proves | Source |
|---|---|---|---|
| DTB root compatible | `fdtget mica.dtb / compatible` | contains `google,mica` → matches on any rev/sku | `fit.c:49-102, 248-289` |
| FIT layout | `dumpimage -l depthcharge.fit` (or `mkimage -l`) | one kernel, one fdt, one ramdisk, `conf-1` | `fit_image.c:339-531` |
| FIT details | `fdtget` on `/configurations default`, `/images/*/compression`, absence of `data-size`/`data-offset` | default kept, FDT and ramdisk uncompressed, embedded data | `fit.c:140-165, 254-259, 484-488` |
| Kernel magic | `od -A d -t x4 -j 56 -N 4 Image` → `644d5241` | depthcharge's header check passes | `boot64.c:43-44, 188-192` |
| Signature chain | `vbutil_kernel --verify mica.kpart --signpubkey …/kernel_subkey.vbpubk --verbose` | keyblock signed by the dev subkey, body signed by the data key | `vb1_helper.c:495-640` |
| Dev-mode path | `vbutil_kernel --verify mica.kpart` (no key) | keyblock hash + body, which is what dev-mode firmware checks | `vb1_helper.c:510-528`; `2load_kernel.c:164-181` |
| Summary | `futility show mica.kpart` | keyblock flags, versions, body size, cmdline | `futility/cmd_show.c:454-`, `file_type.inc:34` |
| Size | body size from `--verify` ≤ `0x10000000` | fits `KERNEL_SIZE` | `2load_kernel.c:389-392` |
| Board rules | `depthchargectl check --config mica.ini --board custom-mica mica.kpart` (`mica.ini` holds the section from [1](#1-mkdepthcharge-for-a-custom-board); `depthchargectl.rst:191-194`, `_check.py:223-224`) | exit 3 size, 4 unreadable, 5 signature, 6 format, 7 missing DTB | `depthchargectl.rst:415-432` |
| Disk | `cgpt show [-i 1 -t\|-P\|-T\|-S] mica-usb.img` | type GUID and attributes | `cgpt/cmd_show.c:19-41` |

**Cannot be exercised without the device:**
- depthcharge's FIT selection. `tests/boot/` at 694eabf has tests for android_mte, bootconfig, commandline,
  memchipinfo and payload, but none for fit (gitiles tree listing, 2026-10-21). The `%U` substitution does have
  `tests/boot/commandline-test.c`.
- The real board-id and sku-id.
- depthcharge's DT fixups on a mainline DT. `dt_apply_fixups` failing aborts the boot (`src/arch/arm/fit.c:99-100`).
- Console output.

## 8. Installing the tools on Arch

| Tool | Arch official | AUR | Debian sid (container) |
|---|---|---|---|
| `mkimage`, `dumpimage` | `extra/uboot-tools` 2026.07-2 (`pacman -Si`, 2026-10-21) | | `u-boot-tools` 2025.01-3.2 |
| `vbutil_kernel`, `futility`, dev keys | none (`pacman -Ss vboot`: no match) | `vboot-utils` 154.16805-1, last modified 2026-10-05 00:45 EDT [04:45 UTC] | `vboot-kernel-utils` 0~R156-16836.B+dfsg-1 |
| `cgpt` | none | in `vboot-utils` | `cgpt` 0~R156-16836.B+dfsg-1 |
| `mkdepthcharge`, `depthchargectl` | none | `depthcharge-tools` 0.6.2-1, flagged out of date 2026-05-06 14:36 EDT [18:36 UTC], last modified 2024-01-05 07:01 EST [12:01 UTC] | `depthcharge-tools` 0.6.2-5 |
| `dtc`/`fdtget`, `lz4`, `xz` | installed (`dtc` 1.8.1, `lz4` 1.10.0, `xz` 5.8.4; `pacman -Q`) | | `device-tree-compiler`, `lz4`, `xz-utils` |

Sources: `pacman -Si`/`-Ss`/`-Q` on the build host; AUR RPC `/rpc/v5/search` and the PKGBUILDs at aur.archlinux.org (read
2026-10-21); `qa.debian.org/madison.php` and `packages.debian.org` file lists (read 2026-10-21). Debian sid
`depthcharge-tools` depends on `cgpt`, `vboot-kernel-utils`, `vboot-utils`, `u-boot-tools`, `device-tree-compiler`,
`lz4`, `xz-utils`, `zstd` and others.

**AUR packages.**
- AUR `vboot-utils` builds `release-R154-16805.B` and runs `make install … MINIMAL=1`, then copies `tests/devkeys`.
  It depends on AUR `cbfstool` and `chromeos-flashrom-git`, which is heavy for three binaries.
- AUR `depthcharge-tools` builds the 2023 v0.6.2 tag with `python setup.py`. It declares only `python` as a
  dependency, so `mkimage`, `vbutil_kernel` and `fdtput` must come from elsewhere.

**Options, in order of preference.**
1. **Container.** `pkexec docker run … debian:sid` with the packages in the Answer. No host install, all official
   packages. vboot is R156 rather than the firmware's branch.
   - *Inference:* the keyblock and preamble formats (2.1/2.2) have not changed between them, and `--verify` uses the
     same verification code the firmware links.
   - A pinned image digest or a Dockerfile in `scripts/` would make it reproducible (not done here).
2. **Arch host.** `pacman -S uboot-tools`, AUR `vboot-utils`, and depthcharge-tools run from the pinned checkout.
   - For example `PYTHONPATH=<checkout> python3 -m depthcharge_tools.mkdepthcharge …`; the module has a `__main__`
     guard (`mkdepthcharge.py:1415`). *Inference:* untested.
   - That needs an owner OK for the installs.
3. **Scratch build.** Build `futil` and `cgpt` from the vboot_reference checkout at 34fbbe6 (`Makefile:360-361`
   defines `futil`). *Inference:* untested; it needs OpenSSL and libuuid headers.

## Not found

- **Board-id and sku-id values.** Neither public source nor the stock dtbo reveals them; only the keyboard overlay's
  board_id range 1-15. The EC console's `cbi` command would show them, but sending it needs the owner's OK under
  [ADR 0006](../adr/0006-debug-console-ccd-suzyq.md).
- **A depthcharge unit test for `fit.c`** at 694eabf, so FIT selection can only be checked by reading the code.
- **Whether `dt_apply_fixups`, including bluey's CPU-map fixup, succeeds on a mainline-shaped DT.** The fixup source
  was not located under `src/board/bluey/` at 694eabf.
- **Whether depthcharge leaves uart21 clocked**, so that `earlycon=qcom_geni` prints before the GENI driver probes.
- **Measured image sizes.** There is no mica kernel build yet, so the 256 MiB margin is not measured.
- **A tested run of the container or AUR route on the build host.** Nothing was installed for this note.
