# Observing a silent first boot on mica

Researched 2026-10-21 from firmware and kernel source at pinned commits, AOSP source, and the stock DT already
extracted from the recovery image ([stock-dtb.md](stock-dtb.md)). Nothing was run on the Googlebook and no SuzyQ
tty was opened. Items marked *inference* are reasoned from source, not tested on the device.

Ticket: `05-silent-boot-observation`.

## Answer

If the AP console (`uart21` through the SuzyQ `-if01`) stays silent, these channels show how far the kernel got.
They are ranked by how much they tell and how little they need from the new kernel.

1. **ramoops: the kernel log of the failed boot, read on the next boot.** This is the best channel.
   - depthcharge always adds `/reserved-memory/ramoops` (`compatible = "ramoops"`) on mica. The buffer is the
     coreboot CBMEM entry `RAMOOPS`, 1 MiB by default, and it sits in CBMEM just below `0x866C0000`.
   - The exact address is decided at boot, not fixed in source. *Inference:* it lies between `0x85F80000` and
     `0x866C0000`.
   - Layout: 256 KiB console, 128 KiB ftrace, 128 KiB pmsg and two 256 KiB dump records. `max-reason = 2` (oops
     and panic).
   - Mainline `a804c57` picks the node up unchanged. The kernel needs `CONFIG_PSTORE=y`, `CONFIG_PSTORE_CONSOLE=y`
     and `CONFIG_PSTORE_RAM=y` built in. arm64 `defconfig` has `PSTORE_RAM=m` and no `PSTORE_CONSOLE`.
   - What to read: `console-ramoops-0` holds every `printk` of the previous boot, up to the hang. A
     `dmesg-ramoops-N` record appears only after an oops or panic.
   - Readback:
     - **(a) Stock OS**, after the next boot: `adb shell cat /sys/fs/pstore/console-ramoops-0`. `adb bugreport`
       also carries it as "LAST KMSG". AOSP grants the shell user both the file mode and the SELinux rule.
       *Inference to test:* the stock kernel has pstore enabled.
     - **(b) The next mainline boot:** `/sys/fs/pstore/`.
     - *Update 2026-10-21 (live read):* on stock build 16560795, `/sys/fs/pstore` is denied to adb shell, so (a) as
       written fails. `adb shell dumpsys dropbox --print SYSTEM_LAST_KMSG` returns the last 64 KiB instead
       (stock pstore ticket).
   - Conditions:
     - DRAM must survive the reset. Let the kernel reboot itself (`panic=5`, plus `softlockup_panic=1` or
       `hung_task_panic=1` for hangs). Do not hold the power button: that is an EC power-off.
     - The next boot must run the same firmware.
2. **The panel, through the firmware framebuffer.**
   - coreboot brings up eDP and draws its splash into a 32 bpp linear framebuffer at `0xE4800000` (region size
     `0x2200000`). It reports that framebuffer in the coreboot table.
   - depthcharge adds **no** `simple-framebuffer` node and does not reserve the region. At handoff it clears the
     screen to black. bluey registers no display driver, so depthcharge has no way to stop the scan-out.
     *Inference:* the panel is still scanning out when the kernel starts.
   - Mainline can use it with `COREBOOT_TABLE`, `COREBOOT_FRAMEBUFFER`, `DRM_SIMPLEDRM` and fbcon. The driver
     registers a `simple-framebuffer` device from the coreboot table, so no width, height or stride needs to go
     into the DTS.
   - The DTS must add a `no-map` reservation for `0xE4800000`+`0x2200000`; the stock overlay does the same with
     its `cont_splash_region`. Without it simpledrm cannot probe: arm64 `ioremap` refuses memory in the linear
     map.
     - *Correction 2026-10-21:* the stock `splash_region` (`entry01-overlay.dts:40-42`) has the same address, but
       its size is `0x21c0000` and it has no `no-map`. The first-boot DTB uses coreboot's `0x2200000` with `no-map`
       (decision).
   - Keep the lid open: coreboot skips display init when the lid is closed.
   - *Inference:* add `clk_ignore_unused pd_ignore_unused`, and do not let the DT turn off the eDP rails, or the
     kernel cuts the display's clocks and power.
3. **EC console (SuzyQ `-if02`), passive.**
   - It logs every AP power-state change (`power state N = S0…`) and AP resets (`AP_RST_L` transitions). It also
     logs `POWER_GOOD` loss and the 8 s long-press power-off.
   - It does not log kernel progress. Host-command tracing is off by default and cannot be turned on through a
     read-only console.
   - Use it as a heartbeat: a kernel that reaches `panic=5`, or an initramfs that runs `reboot -f` or
     `poweroff -f` on purpose, shows up as a reset or an S0→S5 transition.
4. **Firmware log of the previous boot (`/sys/firmware/log`).**
   - coreboot's CBMEM console keeps appending across warm reboots. The next boot's log therefore holds the failed
     boot's firmware lines, including depthcharge's `Choosing best match …` and `jumping to kernel`.
   - It proves depthcharge picked our FIT configuration and jumped. It holds no kernel output.
   - It is readable on a mainline boot with `COREBOOT_MEMCONSOLE`. adb shell on the stock OS is denied
     ([recon](../recon/recon-2026-10-21.md)).
5. **Glowbar / service-LED codes: firmware stage only.**
   - **4,3** matches coreboot's mica-only LCD check, `MAINBOARD_LCD_FAIL_DETECT`. When eDP EDID/DPCD read or link
     training fails in coreboot, it sends the EC lightbar sequence 101 (*inference* that 101 is the 4,3 pattern).
   - **3,5** is the EC's power-on timeout. *Inference:* it is the `POWER_GOOD not seen in time` path.
   - A ramdump pattern (sequence 55) exists, but mainline leaves Qualcomm download mode off.
   - None of these reports kernel progress. The pattern table is in the EC's private module.
6. **GSC `ccdstate`: coarse.** The `AP:` line says whether the AP is powered and out of reset. In cr50 source it
   follows `TPM_RST_L`; Ti50 is closed (*inference* that Ti50 behaves the same). It cannot tell a hung kernel from
   a running one. Its output also prints `pcr0`, which must be redacted before anything is saved.

**For the runbook** (*inference*, for the console-config and failure-playbook tickets):
- **Kernel config:** `PSTORE`, `PSTORE_CONSOLE`, `PSTORE_RAM`, `COREBOOT_FIRMWARE` (the menu that gates the next
  three), `COREBOOT_TABLE`, `COREBOOT_MEMCONSOLE`, `COREBOOT_FRAMEBUFFER`, `DRM_SIMPLEDRM` and
  `FRAMEBUFFER_CONSOLE`, all `=y`.
- **Command line:** `panic=5 softlockup_panic=1`, plus `clk_ignore_unused pd_ignore_unused` while the framebuffer
  is the display.
- **DTS:** a `no-map` region at `0xE4800000`.
- **After a silent boot:** watch the EC console for the reset, let the device fall through to the stock OS, and run
  `adb shell cat /sys/fs/pstore/console-ramoops-0`.
  - Pull the USB drive first, or make sure the internal disk is the default: another mainline boot overwrites the
    zone.
  - Read it before any further reboot: the stock kernel's own log replaces it on the next boot.

## Sources and revisions

| Repo | Commit | Read how |
|---|---|---|
| depthcharge `firmware-bluey-16702.B` | `694eabf646855067acd51935059c3191436ccc79` | blobless clone, 2026-10-21 |
| ChromiumOS coreboot `firmware-bluey-16702.B` | `ff3258d575b0ddf4ba0514a2cd03c6a1936dba69` | blobless sparse clone |
| ChromiumOS EC `firmware-bluey-16702.B-main` | `19b76df3d2722a371141bbac61bf14be79f7a44e` | blobless sparse clone |
| ChromiumOS EC `cr50_stab` (GSC analogue) | `ffacd3c99e6a9090a61439d58d46099f0b5ed09e` | gitiles |
| Linux (torvalds) | `a804c5742bff224d4cb4d25dd383554d598be32b` | raw files at the commit |
| AOSP `platform/system/core` main | `a3b721a32242006b59cb12bd62c9133632af3a2d` | gitiles |
| AOSP `platform/system/sepolicy` main | `4571ddd9440721fec583c906a337de949a77749e` | gitiles |
| AOSP `platform/packages/modules/adb` main | `1cf2f017d312f73b3dc53bda85ef2610e35a80e9` | gitiles |
| AOSP `platform/frameworks/native` main | `4f463a6b1de9198963dc6aff74154a504ba3f8f6` | gitiles |

The 16702.B commits are the ones pinned in [chromeos-boot-path.md](chromeos-boot-path.md). The AOSP commits are
main-branch heads on 2026-10-21. The Googlebook OS build is Android 17 based and its exact AOSP revision is not
public, so AOSP facts are *inference* for the device until read live.

## 1. ramoops

### Where depthcharge puts it

- **The node.** `ramoops_fixup` first deletes any existing node with `compatible = "ramoops"`
  (depthcharge `src/boot/ramoops.c:47-50`). It then calls `dt_add_reserved_memory_region(tree, "ramoops",
  "ramoops", start, size, false)` (`:52-53`).
- **Its shape.** The helper creates `/reserved-memory/ramoops` with a `compatible` string and `reg`, and adds
  `no-map` only when asked (coreboot `src/commonlib/device_tree.c:2171-2198`). Here it is not asked, so the node
  has no unit address and no `no-map`.
- **Properties** (`ramoops.c:36-40, 59-68`):
  - `record-size = 0x40000`, `console-size = 0x40000`, `ftrace-size = 0x20000`, `pmsg-size = 0x20000`;
  - `max-reason = CONFIG_RAMOOPS_DUMP_REASON`;
  - an empty `dump-oops`.
- **`max-reason`.** `RAMOOPS_DUMP_REASON` defaults to 2, or 4 with `RAMOOPS_DUMP_REASON_MAX` (`src/boot/Kconfig:124-135`).
  `configs/config.mica` sets neither, so mica gets 2 = `KMSG_DUMP_OOPS` (kernel `include/linux/kmsg_dump.h:23-30`),
  unless the private board overlay adds `RAMOOPS_DUMP_REASON_MAX`.
- **Address and size** come from coreboot's table: `lib_sysinfo.ramoops_buffer` and `ramoops_buffer_size`
  (`ramoops.c:76-77`). The region is marked used (`:87`), so depthcharge's memory wipe skips it. The wipe runs on
  every non-normal boot, developer mode included (`src/vboot/stages.c:66-71`), and it subtracts used ranges
  first (`src/vboot/util/memory.c:98-100`).
- **Built for mica, on both boot paths.** `ramoops.c` is built when `KERNEL_FIT=y` (`src/boot/Makefile.inc:22`),
  and `config.mica` sets it. `boot()` applies the DT fixups both for an Android DT (`bi->dt`) and for a FIT
  (`src/arch/arm/fit.c:57-99`). So the stock Android kernel gets the same node as ours.
- **The buffer is also covered by a CBMEM reservation.** `dt_update_memory` adds every CBMEM range as a mapped
  `region@<addr>` reservation (`src/boot/dt_update.c:183-193, 219-220`).

coreboot side:
- `ramoops_alloc` does `cbmem_add(CBMEM_ID_RAM_OOPS, CONFIG_CHROMEOS_RAMOOPS_RAM_SIZE)` at `BS_DEV_INIT_CHIPS`.
  `lb_ramoops` then publishes it as `LB_TAG_RAM_OOPS` (`src/vendorcode/google/chromeos/ramoops.c:12-45`), called
  from `src/lib/coreboot_table.c:571-572`.
- `CHROMEOS_RAMOOPS` defaults to y and its size to `0x00100000` (`src/vendorcode/google/chromeos/Kconfig:25-32`).
  bluey's Kconfig does not override it (`src/mainboard/google/bluey/Kconfig`). The board's coreboot defconfig is in
  the private overlay, so 1 MiB is *inference* (the default).
- **Where CBMEM sits.** `cbmem_top_chipset()` returns `_dram_pil` (`src/soc/qualcomm/x1p42100/cbmem.c:7-10`),
  which is `0x866C0000` (`memlayout.ld:289`). CBMEM sits below that.
- **The address is stable, not fixed.** coreboot itself notes that entries created early are "more likely to stay
  in the same place" across boots (`src/lib/cbmem_console.c:169-173`). *Inference:* the same firmware build gives
  the same ramoops address on every boot.
- **A bound from the stock DT.** The stock base DT reserves `wlan-msa@85380000` with size `0xc00000` (ending at
  `0x85F80000`) and `adsp-boot-dtb@866c0000`. *Inference:* the stock kernel would collide with CBMEM if CBMEM
  reached below `0x85F80000`, so ramoops lies in `[0x85F80000, 0x866C0000)`.
- **Mainline overlaps.** Mainline `hamoa.dtsi` has no `no-map` region in that window. Its nearest are
  `spu-secure-shared-memory@85300000` (size `0x80000`) and `adsp-boot-dtb@866c0000` (`hamoa.dtsi`
  `reserved-memory`, read from `.firecrawl/torvalds-a804c57-hamoa.dtsi`).

### Does mainline pick it up unchanged?

Yes, with the right config.

- **Binding.** `reserved-memory/ramoops.yaml` wants a `/reserved-memory` child with `compatible = "ramoops"` and
  `reg`, plus at least one size (`:9-13, 33-62, 113-121`). `max-reason` defaults to 2 (`:76-86`).
  - `dump-oops` is not in the binding (`unevaluatedProperties: false`, `:111`). depthcharge adds it at boot, so it
    never reaches our `dt-validate` run. `ram.c` ignores it; it reads only the deprecated `no-dump-oops`
    (`fs/pstore/ram.c:672-678`).
- **Device creation.** `of_platform_default_populate_init` creates platform devices for `/reserved-memory`
  children that match `"ramoops"` (`drivers/of/platform.c:490-499, 567-571`). It is an `arch_initcall_sync`
  (`:604`). The driver matches `"ramoops"` (`fs/pstore/ram.c:898`).
- **Parsing.** `ramoops_parse_dt` takes the `reg` resource and reads each size and `max-reason` (`ram.c:646-697`).
  Zones are laid out as dump records first, then console, pmsg and ftrace (`ram.c:784-812`). With depthcharge's
  sizes, that leaves `0x80000` for dumps, two 256 KiB records. On probe it prints `ramoops: using 0x…@0x…, ecc: 0`
  (`:869`), which gives the live address on the first mainline boot.
- **Old contents survive probe.** A zone whose header carries the `DBGC` signature is kept as the previous boot's
  record (`fs/pstore/ram_core.c:39, 526-557`). The files are named `<type>-ramoops-<id>` (`fs/pstore/inode.c:365-368`).
- **The console zone gets everything.** The pstore console registers with `CON_PRINTBUFFER`
  (`fs/pstore/platform.c:423`), so it replays the log buffer from boot. A hang before the ramoops probe
  (arch_initcall_sync) leaves the zone with the previous run's content. That stage needs the AP console or earlycon.
- **Config.**
  - `PSTORE`, `PSTORE_CONSOLE` and `PSTORE_RAM` all default to off (`fs/pstore/Kconfig:2-4, 37-39, 68-70`).
  - arm64 `defconfig` has only `CONFIG_PSTORE_RAM=m` (`arch/arm64/configs/defconfig:1928`). A module loads too
    late for early hangs, so the runbook config should set all three `=y`.

### Will DRAM survive the reset?

- **The platform keeps DDR across a warm reset.** bluey's romstage checks the download-mode cookie in shared IMEM
  and, when set, loads Qualcomm's XBL ramdump image to dump memory (`src/mainboard/google/bluey/romstage.c:411-426,
  471-486`; `src/soc/qualcomm/common/qclib.c:566-585`). That only works if DDR contents survive a warm reset into
  coreboot. coreboot also tells warm from cold resets (`romstage.c:459-462`).
- **EC-initiated resets are cold on bluey.** `PLATFORM_EC_POWERSEQ_QC_EXP_WARM_RESET=n` with the comment
  "Bypassing warm reset as it's currently unreliable" (EC `zephyr/program/bluey/program.conf:42-43`).
  `warm_reset_seq()` then logs `Warm reset is disabled, falling back to cold reset` (`power/qcom_exp.c:1041-1084`).
  A long press powers the AP off (`qcom_exp.c:11-23`).
- **An AP-initiated reset does not go through that path.** The EC only counts `AP_RST_L` transitions
  (`qcom_exp.c:262-288`).
- **What the kernel sends.** It issues PSCI `SYSTEM_RESET`, or `SYSTEM_RESET2` (warm) with `reboot=warm` when the
  firmware supports it (`drivers/firmware/psci/psci.c:309-325`).
- *Inference:* a kernel-initiated reboot (`panic=N`) keeps ramoops. A power-button hold or an EC `apreset` may not.
  Whether PSCI `SYSTEM_RESET` is warm here is decided in closed Qualcomm firmware. Test it on the first boot that
  reaches a shell: write a marker to `/dev/kmsg`, `reboot`, and look for it.

### Reading it back

| Where | How | Status |
|---|---|---|
| Stock OS after the failed boot | `adb shell cat /sys/fs/pstore/console-ramoops-0`, or `adb bugreport` ("LAST KMSG") | *Inference to test* |
| Next mainline boot | `cat /sys/fs/pstore/console-ramoops-0`, `dmesg-ramoops-*` | Source-verified, needs config above |
| Firmware console log | Not possible: the kernel log never goes into the CBMEM console | n/a |

Stock-OS evidence (AOSP):
- **Mount and file modes.** `init.rc` mounts pstore at `/sys/fs/pstore` as `system:log 0550`. It makes
  `console-ramoops`, `console-ramoops-0` and `pmsg-ramoops-0` `system:log 0440`
  (`system/core rootdir/init.rc:396-405`).
- **Group.** adbd runs the shell with supplementary group `AID_LOG` (`adb daemon/main.cpp:103, 115`).
- **SELinux.** sepolicy labels pstore `pstorefs` (`private/genfs_contexts:333`) and allows
  `shell pstorefs:dir search` and `shell pstorefs:file r_file_perms` (`private/shell.te:296-299`). A direct `cat`
  of the file should work. `ls` of the directory may be denied, since the shell has only `search`.
- **bugreport.** dumpstate dumps `console-ramoops` or `console-ramoops-0` as "LAST KMSG"
  (`cmds/dumpstate/dumpstate.cpp:172-173, 994-1001`). Its domain has the same read rule
  (`private/dumpstate.te:213-215`).
- **Unknown:** whether the stock kernel builds `PSTORE_RAM` and `PSTORE_CONSOLE`. A one-line live check after any
  stock reboot answers it: `adb shell 'wc -c < /sys/fs/pstore/console-ramoops-0'`. It is a read; it is not run here.
- **One shot.** Only the first boot after the failure holds the mainline log. Each kernel saves the old zone at
  probe and then writes its own console over it (`ram_core.c:526-557`). So the next boot must be the stock OS
  (pull the USB drive or keep the internal disk as the default), and the file must be read before another reboot.
- **Unlocking wipes data.** Unlocking wipes user data ([ADR 0001](../adr/0001-recovery-gates-unlock.md)), so adb has
  to be paired again before this channel works.
- **Address.** The ramoops node has no unit address, so even a listing of `/sys/firmware/devicetree/base/reserved-memory`
  would not give the address. The recon already shows the stock shell is denied DT property reads
  ([recon](../recon/recon-2026-10-21.md)).

## 2. Framebuffer

- **coreboot sets it up.**
  - x1p42100 selects `HAVE_LINEAR_FRAMEBUFFER`, `MAINBOARD_HAS_NATIVE_VGA_INIT` and
    `MAINBOARD_FORCE_NATIVE_VGA_INIT` (`src/soc/qualcomm/x1p42100/Kconfig:22-26`).
  - The memory layout places `FRAMEBUFFER(0xE4800000, 0x2200000)` (`memlayout.ld:296`).
  - bluey's `display_startup()` (`src/mainboard/google/bluey/display.c:158-185`) brings up MDSS and eDP. It reads
    EDID, sets 32 bpp and registers the framebuffer for the coreboot table
    (`fb_new_framebuffer_info_from_edid`, `:179-180`). It then renders the splash and turns on the backlight
    (`:131-156`).
  - It runs on a normal or no-battery boot (`mainboard.c:332-333`). vboot always requests display on this board
    (`VBOOT_ALWAYS_ENABLE_DISPLAY`, bluey `Kconfig:307-311`; `src/security/vboot/vboot_logic.c:311-313`).
  - It is skipped when the lid is closed (`display.c:160-163`).
- **It is not reserved.** `soc_read_resources` lists the firmware carve-outs as reserved RAM, and the framebuffer is
  not among them (`src/soc/qualcomm/x1p42100/soc.c:74-114`). So depthcharge's `/memory` covers it as ordinary RAM.
  The stock overlay reserves `splash_region` at `0xe4800000`, size `0x21c0000`, labelled `cont_splash_region`
  (stock DT overlay entry 1, `fragment@1`), which is the same buffer.
- **depthcharge adds no framebuffer node.**
  - A search of the whole depthcharge tree at `694eabf` finds no `simple-framebuffer` or `simplefb`.
  - Only MediaTek `rauru` adds a framebuffer reservation (`src/board/rauru/board.c:33-59`). bluey's `board.c`
    registers no display ops, and `src/drivers/video/` has no Qualcomm X1 driver.
  - At handoff, `display_cleanup` calls `ui_display_clear()`, which paints black (`src/vboot/ui/display.c:372-376`).
    It then calls `display_stop()`, which with no ops only logs "not implemented"
    (`src/drivers/video/display.c:27-33, 82-108`).
  - *Inference:* the MDP keeps scanning out the black framebuffer with the backlight on when the kernel starts.
- **Mainline can reuse it without a DT node.**
  - depthcharge writes `/firmware/coreboot` (`compatible = "coreboot"`, `reg` = coreboot table and CBMEM)
    (`src/boot/coreboot.c:30-70`). Mainline's `coreboot_table` driver matches it
    (`drivers/firmware/coreboot/coreboot_table.c:261-262`).
  - `COREBOOT_FRAMEBUFFER` (`drivers/firmware/coreboot/Kconfig:83-91`) registers a `simple-framebuffer` platform
    device from `LB_TAG_FRAMEBUFFER`, or `coreboot-framebuffer` with `DRM_COREBOOTDRM`
    (`framebuffer-coreboot.c:107-155`).
  - `DRM_SIMPLEDRM` binds it (`drivers/gpu/drm/sysfb/Kconfig:57-64`).
  - arm64 `defconfig` builds the coreboot table only as a module (`defconfig:270-272`).
- **The `no-map` reservation is required, not optional.**
  - A device from the coreboot table carries only a memory resource. simpledrm therefore maps it with
    `devm_ioremap_wc` and fails the probe when that returns NULL (`drivers/gpu/drm/sysfb/simpledrm.c:775-810`).
  - arm64 `ioremap` returns NULL for any page in the linear map ("ioremap attempted on RAM pfn",
    `arch/arm64/mm/ioremap.c:26-29`). Since depthcharge leaves `0xE4800000` as plain RAM, the DTS must carve it
    out with `no-map`.
- **A hand-written `simple-framebuffer` node is the alternative.** The binding needs `reg`, `width`, `height`,
  `stride` and `format`. It accepts `memory-region`, `clocks`, `power-domains` and `*-supply`
  (`Documentation/devicetree/bindings/display/simple-framebuffer.yaml:58-152`).
  - Width and height come from the panel EDID at boot. They are not in source, so the coreboot-table route needs
    fewer guesses.
- **Keeping it alive** (*inference*). Unused-clock and power-domain cleanup and the regulator core can switch off
  the display path the firmware left on. Use `clk_ignore_unused pd_ignore_unused` and do not declare the eDP rails
  as switchable regulators with no consumer. `DRM_MSM` is a module in `defconfig` (`:1012`), so it will not take
  over unless loaded.

## 3. EC console

Source: EC `19b76df` (`power/qcom_exp.c`, `power/common.c`). bluey sets `CONFIG_AP_ARM_QUALCOMM_QC_EXP=y`
(`zephyr/program/bluey/program.conf:34`).

| EC message | Meaning | Source |
|---|---|---|
| `power state N = S0, in 0x…` (and S5, G3) | every chipset state change | `power/common.c:696` |
| `POWER_GOOD seen` / `POWER_GOOD not seen in time` | AP power-on succeeded / timed out | `qcom_exp.c:874-878` |
| `AP running ...` | power-on sequence done | `qcom_exp.c:1221` |
| `AP_RST_L transitions not expected: N` | an AP reset with an unusual pulse count | `qcom_exp.c:252` |
| `power waiting for long press …`, `power off after long press …` | the 8 s power-button off | `qcom_exp.c:976-987` |
| `POWER_GOOD is lost` | the AP dropped its power-good: shutdown | `qcom_exp.c:995` |
| `chipset_reset(N)` then `Warm reset is disabled, falling back to cold reset` | EC-initiated reset | `qcom_exp.c:1081, 1107` |

- **Host-command tracing is off by default.** `HCDEBUG_OFF` is the default unless `PLATFORM_EC_BRINGUP`
  (`zephyr/Kconfig:557-562`), and turning it on needs a console write. The SuzyQ EC console is receive-only while
  CCD is locked ([ccd-gsc.md](ccd-gsc.md): `UARTEC` without `+TX`).
  - So the EC console cannot show the kernel's `cros-ec` traffic.
  - It does show a kernel that reboots or powers off on purpose.
- The stock log seen 2026-10-21 (`I: ADSP: Charging from USB0`) comes from the ADSP, which coreboot starts. It says
  nothing about the kernel.

## 4. Firmware console log

- **It persists.** The CBMEM console "will persist across multiple boots and append to the previous log" when the
  storage allows (`src/lib/cbmem_console.c:10-17`).
  - A valid header found at the new CBMEM console address is kept, not reset (`:58-79`).
  - The console is created early "so that the console region … [is] more likely to stay in the same place"
    (`:159-173`).
  - The same DRAM-retention condition as ramoops applies.
- **What it shows of the failed boot.** depthcharge prints `Choosing best match <config> for compat <string>.`
  (`src/boot/fit.c:439`) and `jumping to kernel` (`src/arch/arm/boot64.c:215`).
- **Where to read it.** Mainline exposes it as `/sys/firmware/log` with `COREBOOT_MEMCONSOLE`
  (`drivers/firmware/coreboot/Kconfig:93-101`; `memconsole.c:29-42`). The stock adb shell is denied that file
  ([recon](../recon/recon-2026-10-21.md)).
  - Firmware fastboot's `oem logs` is another reader, but it needs the USB-Ethernet route
    ([boot path, section 4](chromeos-boot-path.md#4-firmware-fastboot)).
- **On the AP UART.** coreboot loads the console UART's QUP firmware "even if coreboot's serial output is disabled"
  (`src/mainboard/google/bluey/mainboard.c:290-297`, `QUPV3_2_SE5`). That is `uart21`
  ([ADR 0006](../adr/0006-debug-console-ccd-suzyq.md)). Whether production firmware prints there
  (`CONSOLE_SERIAL`) is in the private defconfig. The stock-boot capture in [ccd-gsc.md](ccd-gsc.md#open) answers it.

## 5. Glowbar and service-LED codes

Dell's codes (project log, Service Manual page 64): **3,5** power-rail failure (an SoC power-on
timeout seen by the EC); **4,3** LCD failure (EDID/DPCD read or eDP link training failed; it boots on after 10
minutes).

- **mica's LED setup.** mica selects `EC_GOOGLE_CHROMEEC_LED_CONTROL`, `MAINBOARD_LCD_FAIL_DETECT` and
  `MAINBOARD_RAMDUMP_LED_NOTIFICATION` (bluey `Kconfig:79-92`).
- **The LCD check.** It is documented as reading EDID/DPCD and running link training in the preboot phase, then
  telling the EC (`Kconfig:209-216`). Its sequence number is `MAINBOARD_LIGHTBAR_CMD_SEQ_DIAG_LCD`, 101 on mica
  (`:218-224`).
  - `qcom_mdss_edp_init` sends it when `edp_ctrl_init` fails (`display.c:72-83`).
  - The call is `EC_CMD_LIGHTBAR_CMD` / `LIGHTBAR_CMD_SEQ` (`src/ec/google/chromeec/ec.c:2266-2284`).
  - *Inference:* sequence 101 is Dell's 4,3. It reflects coreboot's eDP bring-up, before any kernel runs.
- **The ramdump pattern.** On download-mode entry coreboot sends sequence 55 (`MAINBOARD_LIGHTBAR_CMD_SEQ_RAMDUMP`,
  `Kconfig:387-402`; `romstage.c:476-482`). Mainline's `qcom_scm.download_mode` defaults to 0
  (`drivers/firmware/qcom/qcom_scm.c:41, 2749-2750`), so a mainline panic should not trigger it.
- **3,5 lives in the EC.** The public lightbar sequence list stops at 12 (`include/lightbar_msg_list.h:9-22`).
  mica builds with `CONFIG_GOOGLE_PRIVATE=y` (`zephyr/program/bluey/mica/project.conf:9`), and sequences 55 and 101
  are not public. *Inference:* 3,5 is raised from the EC power sequencer's `POWER_GOOD not seen in time` path
  (`qcom_exp.c:874`). That would be a firmware/PMIC-stage failure, not a kernel one.
- **A deliberate beacon** (*inference, untested*). Mainline's `cros-ec-lightbar` is added when the EC reports
  `EC_FEATURE_LIGHTBAR` (`drivers/mfd/cros_ec_dev.c:299-311`). Its `sequence` sysfs file accepts a number
  (`drivers/platform/chrome/cros_ec_lightbar.c:433-470`). If mica's EC advertises the feature, an initramfs could
  flash the Glowbar at a checkpoint. That needs a working `cros-ec-spi`, so it is a late-stage signal.

## 6. GSC `ccdstate`

- **What `ccdstate` prints.** In cr50 (the public GSC firmware), `ccdstate` prints the AP state, the AP UART state,
  `pcr0`, the EC, servo and Rdd states, `CCD_MODE` and the state flags (`board/cr50/rdd.c:473-490`).
- **How the AP state is tracked.** It follows `TPM_RST_L`: `AP on` when it deasserts, `AP off` after it has been
  asserted for a while (`board/cr50/ap_state.c:119-132, 186-187, 240`). The `AP:` line adds `K` or `F` for kernel
  or firmware (`:24-29`).
- **Ti50.** Ti50's source is not public. The 2026-10-21 read showed `AP on` ([ccd-gsc.md](ccd-gsc.md)).
  *Inference:* Ti50 uses the same signal.
- **Use.**
  - It shows whether the AP is held in reset or powered off. It cannot show where a running kernel stopped.
  - The command is on ADR 0006's allowed list.
  - `ccdstate` output includes `pcr0`, a per-unit value: redact it before saving.

## Not found

- **The live ramoops address and size.** CBMEM allocation is dynamic. The first mainline boot prints it
  (`ramoops: using …`). The stock shell cannot read the DT.
- **mica's coreboot defconfig** (private overlay): `CHROMEOS_RAMOOPS_RAM_SIZE`, `CONSOLE_SERIAL`,
  `CONSOLE_CBMEM_BUFFER_SIZE` and `BMP_LOGO`.
- **Whether the stock Googlebook kernel builds `PSTORE_RAM`/`PSTORE_CONSOLE`** and mounts pstore. AOSP policy allows
  the read; the kernel config is not public.
- **Whether PSCI `SYSTEM_RESET` on this firmware keeps DDR.** It is decided in Qualcomm firmware outside coreboot's
  public tree. Only an on-device test answers it.
- **The EC Glowbar pattern table** (sequences 55, 101 and the 3,5 trigger). It is in the EC `google-private` module.
- **Whether mica's EC advertises `EC_FEATURE_LIGHTBAR`.**
- **Ti50 `ccdstate` semantics.** No public Ti50 source; cr50 is used as the analogue.
- **What writes the 64 KiB `dram_dc_log` region at `0x81CE4000`.** coreboot reserves it
  (`src/soc/qualcomm/x1p42100/memlayout.ld:281`, `soc.c:97`), and the stock DT names it `depthcharge-log`
  (`no-map`). Mainline `hamoa.dtsi` calls the same address `uefi-log`. No writer exists in depthcharge `694eabf` or
  coreboot `ff3258d`.
