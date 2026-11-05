# Exception level at kernel entry on mica, and `x1-el2.dtso`

Researched 2026-10-21 from firmware and kernel source at pinned commits, the stock DT extracted from the recovery
image, and the existing recon. The device was not touched. Resolves
ticket 02.

## Answer

1. **mica's firmware enters Linux at EL2.** coreboot asks BL31 (TF-A) to start the payload at EL2. depthcharge
   (built on libpayload) runs at EL2 and jumps to the kernel with a plain branch, with no `eret`. The Android and the
   FIT routes both use that same jump. The bluey firmware has no Gunyah or other Qualcomm hypervisor: on the application
   cores it starts only BL31 (EL3), QTEE (secure EL1) and depthcharge. AOP, CPUCP, SHRM and ADSP-lite firmware go to
   other processors. On stock, EL2 belongs to the Android kernel's pKVM
   (`kvm-arm.mode=protected`).
2. **Apply `x1-el2.dtso`.** Either build `x1e80100-google-mica-el2.dtb` from `mica.dtb` + `x1-el2.dtbo` (the
   way the Makefile does it for the 9345), or put the same changes in the mica DTS directly, as the sc7180/sc7280
   Chromebook trees do. mica has no Gunyah variant, so the plain-EL1 DTB has nothing to boot on. The overlay applies
   cleanly to the current draft and passes `dt-validate` (section 5).
3. **What breaks without it** (*inference* from the overlay's comments and the drivers):
   - **First-boot risk:** `sbsa_watchdog` stays enabled. Its comment says it "is implemented in software in Gunyah
     and can't be used when running in EL2". If `CONFIG_ARM_SBSA_WATCHDOG` probes a watchdog that does not exist,
     the result is unknown. Separately, `apss_watchdog` (the real hardware watchdog) stays `reserved`.
   - **As soon as NVMe or Wi-Fi is on:** `pcie_smmu` stays `reserved` and `pcie4`/`pcie6a` get no `iommu-map`.
     Under Gunyah, firmware programs that SMMU; at EL2 nobody does.
   - **Phase 3:** the GPU tries to load a zap shader through PAS, IRIS tries PAS boot (broken at EL2, per commit
     `c0f045e`), and the ADSP/CDSP lack the `iommus` that the PAS driver needs to map their firmware.
4. **Applying it wrongly** means applying it under a hypervisor that owns the PCIe SMMU and APSS watchdog. Linux
   would then fight that hypervisor for both. That cannot happen on this firmware.

## 1. Firmware chain: who runs at which EL

Sources: ChromiumOS coreboot `firmware-bluey-16702.B` at `ff3258d575b0ddf4ba0514a2cd03c6a1936dba69` and depthcharge
`firmware-bluey-16702.B` at `694eabf646855067acd51935059c3191436ccc79`
([pinned in chromeos-boot-path.md](chromeos-boot-path.md#sources-and-revisions)). Read 2026-10-21.

| Step | Evidence |
|---|---|
| coreboot starts at **EL3** | `src/arch/arm64/Kconfig:26-28`: `ARM64_CURRENT_EL` defaults to 3. Neither `src/soc/qualcomm/x1p42100/Kconfig` nor `src/mainboard/google/bluey/Kconfig` nor `src/soc/qualcomm/common/Kconfig` overrides it (no `CURRENT_EL` in any of the three) |
| It uses TF-A, which needs EL3 | `src/soc/qualcomm/x1p42100/Kconfig:11` `select ARM64_USE_ARM_TRUSTED_FIRMWARE`; `src/arch/arm64/Kconfig:44-47` `depends on … ARM64_CURRENT_EL = 3` |
| The payload is requested at **EL2** | `src/arch/arm64/boot.c:17-20`: `payload_spsr = get_eret_el(EL2, SPSR_USE_L)`, passed to `run_bl31()` |
| BL31 gets that SPSR for BL33 | `src/arch/arm64/bl31.c:108-110`: `bl33_ep_info.spsr = payload_spsr` |
| The secure OS runs at **secure EL1** | `bl31.c:88-104`: BL32 loaded from CBFS `secure_os`, `spsr = get_eret_el(EL1, …)`. Hamoa selects `ARM64_USE_SECURE_OS` (`x1p42100/Kconfig:48-52`) |
| depthcharge's runtime **runs at EL2** | libpayload `payloads/libpayload/arch/arm64/head.S:38` writes `sctlr_el2` and `:42` writes `hcr_el2` (`HCR_TGE`) at `_entry`. Those writes are undefined below EL2 (Arm ARM DDI 0487, `MSR` to an `*_EL2` register from EL1 is UNDEFINED), and depthcharge visibly runs on mica. Also `arch/arm64/mmu.c:84` ("We should be in EL2…") and `exception_asm.S:97-126` (`spsr_el2`, `elr_el2`) |
| depthcharge **does not change EL** before the kernel | depthcharge `src/arch/arm/boot64_asm.S:38-46`: TLB invalidate, MMU off, `x0 = fdt`, then `br x25`. No `eret`, no SPSR write |
| Both boot routes use that jump | `src/arch/arm/fit.c:57-124`: `boot()` takes `bi->dt` (the Android dtbo route) or `fit_load()` (the ChromeOS FIT route), then `boot_arm_linux()`. That is `boot64.c:166-229`, ending in `boot_arm64_linux_jump()` |

**No hypervisor image in the bluey build.** `src/soc/qualcomm/x1p42100/Makefile.mk:88-431` lists every Qualcomm blob
put into CBFS: QcLib, DCB, pre-DDR DTB, CPR, QUP firmware, AOP, CPUCP, ADSP-lite, SHRM, the QTEE configs
`tzoem_cfg`/`tzqti_cfg`, the access-control configs `tzac_cfg`/`hypac_cfg`, APDP and ramdump. TF-A (`bl31`) and
QTEE (`secure_os`) come from the arch Kconfig. No hypervisor image (`hyp.mbn`, Gunyah, QHEE) is there.
`src/soc/qualcomm/x1p42100/soc.c:115-147` loads the four configs, then preloads `bl31` and `secure_os`, and nothing
else.

**DRAM map agrees.** `src/soc/qualcomm/x1p42100/memlayout.ld:267-268` puts coreboot's own post-RAM stack at
`0x80000000`. On Windows-firmware boards, mainline reserves that address as `gunyah_hyp_mem` (`hamoa.dtsi:482-485`
at `a804c57`). TZ is at `0xD8000000`, with BL31 right after it (`:293-294`). *Inference:* the mainline `gunyah_hyp_mem`
reservation wastes 8 MiB on mica and does no harm.

**Stock agrees.** Recon 2026-10-21 ([`recon-2026-10-21.md`](../recon/recon-2026-10-21.md) rows 19 and 21):
- the command line has `kvm-arm.mode=protected` and `id_aa64mmfr1.vh=0`, plus `kvm-arm.protected_modules=` with
  `pkvm-smc-filter.ko` and `qcom_smmu_v2_v3_dispatcher.ko`;
- `ro.boot.hypervisor.protected_vm.supported=1`.

Protected KVM installs its hypervisor at EL2 from the kernel, and the kernel can only do that if it was entered at
EL2. depthcharge also loads pvmfw and adds its reserved-memory node for pKVM (`src/arch/arm/fit.c:79-97`,
`CONFIG_ANDROID_PVMFW=y` in `configs/config.mica`). *Inference:* on stock, pKVM plus its Qualcomm SMMU and SMC
modules fill the role that Gunyah fills on Windows laptops.

Linux allows either level: "The CPU must be in non-secure state, either in EL2 (RECOMMENDED in order to have access
to the virtualisation extensions), or in EL1." (`Documentation/arch/arm64/booting.rst:174-175` at `a804c57`)

## 2. What `x1-el2.dtso` changes, and why

File: `arch/arm64/boot/dts/qcom/x1-el2.dtso` at torvalds/linux `a804c5742bff`. History read through the GitHub
commits API for that path on 2026-10-21 (four commits):

| Commit (author date) | Change | Reason given |
|---|---|---|
| `e01acd8f3cc1` (2025-05-03) "x1e/x1p: Add EL2 overlay for WoA devices" | creates the overlay and the `-el2.dtb` Makefile targets | "WoA devices using x1e/x1p use android firmware to boot, which notably includes Gunyah hypervisor … Linux-based OS could only boot in EL1." With `slbounce` Linux can take EL2, and "some modifications to the DT are necessary to facilitate the absence of Gunyah services" |
| `c0f045e303e0` (2025-09-15) "x1-el2: Disable IRIS for now" | `&iris { status = "disabled" }` | Reset and IOMMU handling for IRIS live in the hypervisor on X1E. At EL2 "the PAS interface normally used by IRIS to boot the video firmware is not working" |
| `f010e0b99703` (2025-12-24) "x1-el2: Enable the APSS watchdog" | `&apss_watchdog { status = "okay" }` | "In EL2, the APSS watchdog is available" |
| `47c88db49f6c` (2026-02-03) "hamoa: Add remoteproc IOMMUS in EL2 device trees" | `iommus` for `remoteproc_adsp` (`0x1000 0x80`) and `remoteproc_cdsp` (`0x0c00 0x0`) | "without Gunyah, the IOMMU is managed by the consumer of this DeviceTree. Therefore, describe the firmware streams" |

The whole overlay (`x1-el2.dtso:10-69`):
- `apss_watchdog` okay;
- `gpu_zap_shader` disabled ("linux can zap the gpu on it's own");
- `iris` disabled;
- `pcie3`, `pcie4`, `pcie5`, `pcie6a` get `iommu-map` onto `pcie_smmu` (stream bases `0x30000`, `0x40000`,
  `0x50000`, `0x60000`);
- `pcie3` and `pcie5` also get `msi-map` onto `gic_its` ("ITS emulation in Gunyah is broken");
- `pcie_smmu` okay;
- the remoteproc `iommus` above;
- `sbsa_watchdog` disabled.

The mainline defaults it overrides are in `hamoa.dtsi` (`a804c57`):
- `pcie_smmu` is `status = "reserved"; /* Controlled by Gunyah. */` (`:8520-8532`);
- `apss_watchdog` is `"reserved"; /* Reserved by Gunyah */` (`:8560-8566`);
- `sbsa_watchdog` has no status, so it is enabled (`:8777-8782`);
- `pcie4` and `pcie6a` already have `msi-map` (`:3721`, `:3441`), so mica's two PCIe controllers have MSIs either way.

The `Makefile` builds `x1e80100-dell-xps13-9345-el2.dtb := x1e80100-dell-xps13-9345.dtb x1-el2.dtbo` (`:440-441`).
That is the board mica's DTS is drafted from ([ADR 0004](../adr/0004-device-tree-from-9345.md)).

## 3. Chromebook precedent: Qualcomm Chrome trees carry the same changes

Older Qualcomm Chromebooks boot the same way: coreboot, TF-A and depthcharge, with no QHEE. Their mainline trees
already contain what the WoA EL2 overlays add:
- `sc7180-el2.dtso:15`: "Venus can be used in EL2 if booted similarly to ChromeOS devices". Commit `0d95f64be417`
  (2025-05-03): WoA sc7180 "includes QHEE hypervisor", hence EL1.
- `sc7180-trogdor.dtsi:44` `/delete-node/ &gpu_zap_shader;` and `:45` `/delete-node/ &hyp_mem;`;
  `:1005-1008` adds `video-firmware { iommus = … }` to Venus. That is the same zap and video change `sc7180-el2.dtso`
  makes.
- `sc7280-chrome-common.dtsi:3-9` ("memory protections put into place by the Chrome bootloader … different than …
  Qualcomm's typical bootloader") deletes `gpu_zap_shader` and `hyp_mem` (`:23-24`) and sets
  `&watchdog { status = "okay"; }` (`:143-145`). In the base tree that watchdog is `status = "reserved"; /* Owned by
  Gunyah hyp */` (`kodiak.dtsi:6918-6923`).

*Inference:* mica's bluey firmware is the same design one generation later, so it needs the same DT treatment. For
X1 that treatment is already packaged as `x1-el2.dtso`.

## 4. Against the stock mica tree

Derived facts from the recovery-image base DTB (`dumps/recovery-16471258/dtbo/entry00-base.dts`, gitignored;
reproduce with `scripts/extract-stock-dtb.sh`, see [stock-dtb.md](stock-dtb.md)). Line numbers refer to that
decompiled file.

| Overlay item | Stock mica | Fits EL2 without Gunyah? |
|---|---|---|
| `pcie_smmu` (`arm,smmu-v3` at `0x15400000`) | present with no `status`, so enabled (`:13161-13171`) | yes: Android owns it (through pKVM's SMMU module) |
| `pcie4` / `pcie6a` `iommu-map` | `pcie4` maps onto `pcie_smmu` at `0x40000`, `pcie6` at `0x60000` (`:14378`, `:14288`) | yes: **the same stream bases as the overlay** |
| APSS watchdog at `0x17410000` | `qcom,msm-watchdog`, enabled (`:12829-12839`) | yes: HLOS owns it, as at EL2 |
| `sbsa_watchdog` (`arm,sbsa-gwdt` at `0x1c840000`) | present, enabled (`:10597-10601`) | **counter-signal**, see below |
| GPU `zap-shader` | a `zap-shader` child exists under the GPU (`:11731`) | **counter-signal**, see below |
| ADSP/CDSP `iommus` | none on `qcom,x1e80100-adsp-pas` (`:5512-5537`) | neutral: stock PAS goes through pKVM and the vendor driver |
| PCIe MSI | `msi-parent` points at `qcom,pci-msi` controllers (`:14324-14331`); the GIC ITS is a `pkvm,protected-region` (overlay 1) | neutral: vendor pKVM detail ([9345-dts-diff.md](9345-dts-diff.md)) |

Counter-signals, and why the overlay is still right:
- **`hypac_cfg`.** coreboot loads a "hyp access-control" config (`hyp_ac_config.elf`, `Makefile.mk:371-376`,
  `soc.c:135-138`). Which component reads it is not public. Nothing besides BL33 is ever entered at EL2 (section 1),
  so it does not mean there is a hypervisor. *Inference:* QTEE or TF-A applies it as a policy.
- **Stock enables the SBSA watchdog.** That cuts against the overlay's comment that Gunyah emulates it. The stock
  tree is a Qualcomm vendor base, and enabling a node does not show anything exists at `0x1c840000`. Disabling it is
  safe either way. Leaving it enabled is the only one of the two choices that can go wrong at first boot.
- **Stock keeps a zap-shader node.** ChromeOS precedent goes the other way (section 3: trogdor and chrome-common
  delete it). *Inference:* the stock node serves Android's pKVM and vendor-driver path, not mainline's.
  `adreno_gpu.c:49-52` at `a804c57` treats a missing or disabled `zap-shader` as "zap not available" (`-ENODEV`).
  It then takes the zap-less path. The overlay's own comment says that path works at EL2: "linux can zap the gpu on
  it's own" (`x1-el2.dtso:14`).

## 5. Check: the overlay applied to the draft DTS

Run 2026-10-21 on the build host in a scratch directory (nothing committed):
1. `scripts/build-dtb.sh` compiles with `dtc -@` (line 17), so the base keeps `__symbols__`.
2. `dtc -@ -I dts -O dtb x1-el2.dtso` and `fdtoverlay -i mica.dtb -o mica-el2.dtb x1-el2.dtbo` applied with no
   errors.
3. `dt-validate -s schema-a804c57.json mica-el2.dtb` reported only the known pending `google,mica` root-compatible
   finding, the one `scripts/check.sh` already allows.
4. `fdtget` before → after:
   - `iommu@15400000`: reserved → okay;
   - `watchdog@17410000`: reserved → okay;
   - `watchdog@1c840000`: (enabled) → disabled;
   - `video-codec@aa00000`: okay → disabled;
   - `pcie@1c08000` `iommu-map` = `0 <pcie_smmu> 0x40000 0x10000`;
   - `pcie@1bf8000` = `… 0x60000 0x10000`.

The draft `dts/x1e80100-google-mica.dts` sets `&gpu_zap_shader { firmware-name }` (`:748-750`) and
`&iris { status = "okay" }` (`:959-962`), following the 9345. The overlay disables both, which is intended at EL2.

Packaging note for the FIT ticket: depthcharge can apply overlays itself. A FIT configuration's `fdt` property may
list a base followed by overlays (`src/boot/fit.c:115-134`, `:177-178`), applied with `dt_apply_overlay()`
(`:464-479`). The configuration also needs a `compatible` (`:261-263`). Applying it at build time is simpler and
matches the kernel Makefile.

**Watchdog left armed by firmware?** coreboot's common Qualcomm `watchdog.c` (`src/soc/qualcomm/common/watchdog.c:10-16`,
linked in romstage at `x1p42100/Makefile.mk:34`) only reads the AOSS reset status to record a tombstone. It does not
arm a watchdog. *Inference:* a kernel without `apss_watchdog` will not be reset by a firmware-armed watchdog. The
depthcharge watchdog code was not read (only part of depthcharge is cached).

## Not found

- **TF-A's Qualcomm platform code** that reads `bl33_ep_info.spsr`. coreboot uses a prebuilt BL31 plus
  `libqtisec.a` (`Makefile.mk:99-104`). That BL31 honours the requested EL2 is inferred from the stock pKVM evidence;
  its source was not read.
- **Who reads `hypac_cfg`**, and what policy it applies.
- **What is at `0x1c840000` on mica**, and whether the SBSA watchdog exists there without Gunyah.
- **Whether mica's QTEE supports the PAS resource-table SCM call.** With `iommus` present, `qcom_q6v5_pas.c` takes
  that path (`:862` `has_iommu`, `:475-500` `qcom_pas_get_rsc_table()`, `:927` `use_tzmem`). It decides whether
  ADSP/CDSP boot at EL2 (Phase 3).
- **The state firmware leaves the PCIe SMMU in** (enabled, bypass or abort) when Linux leaves it alone, which decides
  how NVMe fails without the overlay.
- **Anything on exception levels in `chromebook-boot-flow.rst`.** At `a804c57`
  (`Documentation/arch/arm/google/chromebook-boot-flow.rst`) it covers FIT compatible matching only.
- **A boot log showing `CPU: All CPU(s) started at EL2`.** It would confirm this answer, and the first boot
  (or ramoops) will show it.
- **The full depthcharge tree** at `694eabf`: only the files under `.firecrawl/src-depthcharge-…` were read.
