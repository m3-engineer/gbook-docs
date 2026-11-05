# Kernel configuration fragments

Merged onto the arm64 defconfig in name order after `mica-firstboot.config` (`scripts/build-kernel.sh`). A `# require:`
line must end `=y` in the result; a `# forbid-y:` line must not. Each fragment's own header follows. Also here:
[`firmware.sha256`](firmware.sha256) (hashes of the vendor firmware the initramfs stages; the blobs are not
redistributed), [`dt-gaps.txt`](dt-gaps.txt) and [`known-failures.txt`](known-failures.txt).

## [`mica-adsp.config`](mica-adsp.config)

```
Phase 3, ADSP: boot the audio DSP so pmic_glink (Type-C orientation and mode, battery) can come up.
Source: the USB run (docs/recon/usb-2026-11-02.md): pmic-glink stayed deferred with "failed to initialize pdr".
Firmware: the stock modem_a partition's image/adsp.mdt + .bNN and adsp_dtb.mdt + .bNN (build
ADSP.HT.5.9.c5-00032.4-HAMOA-1), packed into the initramfs from ~/.cache/gbook/firmware (ADR 0005: not in git).
The remoteproc driver for qcom,x1e80100-adsp-pas and its helpers (all =m in defconfig at a804c57).
require: REMOTEPROC
require: RPMSG_QCOM_GLINK
require: QCOM_SMEM
require: QCOM_SMP2P
require: QCOM_AOSS_QMP
require: QCOM_IPCC
require: QCOM_PDR_HELPERS
require: QCOM_QMI_HELPERS
require: FW_LOADER
```

## [`mica-audio.config`](mica-audio.config)

```
M3, audio (ticket 10, 2026-11-04): the sound card of the board DTS (dts/diag/sound.dtsi until 2026-11-05; 4x WSA8845 on swr0 and swr3, 4 DMICs on
the VA macro, the ADSP's APM and PRM services over GPR). scripts/dt-kconfig-map.py on the sound -el2 DTB,
2026-11-04: every driver below was =m, and the initramfs loads no modules. The topology
qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin is requested at the card's component probe
(sound/soc/qcom/qdsp6/topology.c:1422, q6apm.c q6apm_audio_probe), so scripts/stage-firmware.sh puts it in the
initramfs. Firmware-side: the stock ADSP (adsp.mdt) must offer the "avs/audio" protection domain; QCOM_PD_MAPPER
and QCOM_PDR_HELPERS are =y already (pmic_glink uses them).
require: SND_SOC_QDSP6_COMMON
require: SND_SOC_QDSP6_APM
require: SND_SOC_QDSP6_APM_DAI
require: SND_SOC_QDSP6_APM_LPASS_DAI
require: SND_SOC_QDSP6_PRM
require: SND_SOC_QDSP6_PRM_LPASS_CLOCKS
require: SND_SOC_QCOM_COMMON
require: SND_SOC_QCOM_SDW
require: SND_SOC_TOPOLOGY
require: SND_SOC_LPASS_MACRO_COMMON
require: REGMAP_SOUNDWIRE
require: QCOM_PDR_HELPERS
require: QCOM_PD_MAPPER
require: RPMSG_QCOM_GLINK_SMEM
```

## [`mica-bt.config`](mica-bt.config)

```
M2, Bluetooth (owner, 2026-11-04 park round: "test"): the WCN7850's Bluetooth on uart14 (dts: &uart14 { bluetooth {
compatible = "qcom,wcn7850-bt" } }). scripts/dt-kconfig-map.py names BT_HCIUART (=m in arm64 defconfig) for it, so
the node never bound. hci_uart's QCA protocol (BT_HCIUART_QCA, already =y) probes it over serdev, powers it through
the WCN power sequencer (pwrseq-qcom-wcn) and, when the core powers the new controller on, downloads
qca/hmtbtfw<rom>.tlv and an NVM file chosen by board id (btqca.c:825-827, 919-921, qca_get_nvm_name_by_board at
a804c57); scripts/stage-firmware.sh stages all five hmtnv20.* candidates. No userspace (no BlueZ): the controller
is set up, then the core powers it off again; nothing scans or pairs.
require: BT_HCIUART_SERDEV
require: BT_HCIUART_QCA
require: SERIAL_DEV_BUS
require: SERIAL_QCOM_GENI
require: POWER_SEQUENCING_QCOM_WCN
```

## [`mica-console.config`](mica-console.config)

```
The owner's view on the Googlebook's own panel (2026-11-03): /init mirrors a readable status page to tty1 (fbcon on
the eDP panel; the kernel console stays on the serial port, console=ttyMSM0). The default 8x16 font gives 320x100
characters on the 2560x1600 13.4" panel, too small to read at arm's length; Terminus 16x32 gives 160x50
(lib/fonts/Kconfig:126-134). The command line selects it with fbcon=font:TER16x32 (scripts/package-in-container.sh).
require: FRAMEBUFFER_CONSOLE
require: DRM_FBDEV_EMULATION
require: VT_CONSOLE
```

## [`mica-debug.config`](mica-debug.config)

```
Event tracing for the boot captures (owner round 2026-11-03: 1a), docs/research/debug-tools.md option 1.
arm64 defconfig:1970 sets "# CONFIG_FTRACE is not set", so the kernel had no tracefs and no trace events. The command
line (scripts/package-in-container.sh) arms scmi, i2c and qcom_geni_i2c events with trace_event= from start_kernel;
/init saves a filtered copy into the netlog. ENABLE_DEFAULT_TRACERS selects TRACING, which selects EVENT_TRACING,
RING_BUFFER and TRACEPOINTS (kernel/trace/Kconfig:179-188, :588-591). No function tracer.
require: EVENT_TRACING
require: TRACEPOINTS
```

## [`mica-display.config`](mica-display.config)

```
Phase 3, display: msm DRM drives the eDP panel, so the panel stays lit after the regulator core's unused-supply
cleanup. Source: attempt 2026-11-03-3 (docs/recon/wifi-2026-11-03.md): "VREG_EDP_3P3: disabling" at about 33 s,
because only simpledrm drives the screen and nothing claims the panel supply. The mica DTS already describes the
path (&mdss, &mdss_dp3 with an edp-panel on its aux-bus, &mdss_dp3_phy, pwm-backlight); every driver on it is =m
in defconfig at a804c57 and the initramfs loads no modules.
The GPU is left out: the command line carries msm.skip_gpu=1 (scripts/package-in-container.sh), because the GPU
would join the MDSS component match (drivers/gpu/drm/msm/msm_drv.c:1076-1086) and wait on gpucc.
MDSS/DPU/DP (drivers/gpu/drm/msm/Kconfig:3). Sub-options DPU, DP and KMS_FBDEV default to y.
require: DRM
require: DRM_MSM_DPU
require: DRM_MSM_DP
require: DRM_MSM_KMS_FBDEV
require: DRM_FBDEV_EMULATION
require: PWM
require: REGULATOR_FIXED_VOLTAGE
require: DRM_AUX_HPD_BRIDGE
```

## [`mica-ec.config`](mica-ec.config)

```
Phase 3, EC: the ChromeOS EC on spi13, its keyboard and its children (owner round 2026-11-03: 1a 2a).
Source: every boot on 2026-11-03 (10 in dumps/firstboot/2026-11-03-netlog.txt) logs 77 lines of
"sync_state() pending due to a94000.spi" and not one cros_ec line. a94000 is spi13 (hamoa.dtsi:1905), the bus of
cros_ec ec@0 in dts/x1e80100-google-mica.dts. Its driver (qcom,geni-spi, drivers/spi/Kconfig:1013) is =m in arm64
defconfig, and the initramfs loads no modules, so the EC and cros-ec-keyb never probed.
The EC's children are MFD cells that cros_ec_dev adds per EC feature (drivers/mfd/cros_ec_dev.c:106-153):
cros-keyboard-leds for EC_FEATURE_PWM_KEYB ("chromeos::kbd_backlight", cros_kbd_led_backlight.c:201), the EC LEDs,
and the cros_ec hwmon (fan RPM, temperatures; SENSORS_CROS_EC is already =y).
require: CROS_EC
require: CROS_EC_SPI
require: CROS_EC_PROTO
require: MFD_CROS_EC_DEV
require: KEYBOARD_CROS_EC
require: SENSORS_CROS_EC
forbid-y: CROS_EC_TYPEC
forbid-y: CROS_EC_UCSI
```

## [`mica-firstboot.config`](mica-firstboot.config)

```
First-boot config fragment for mica, merged onto arm64 defconfig at torvalds/linux a804c57:
  scripts/kconfig/merge_config.sh -m arch/arm64/configs/defconfig kernel/mica-firstboot.config
  make ARCH=arm64 LLVM=1 olddefconfig
Decided in .scratch/phase-2-first-boot/issues/06-kernel-tree.md (inputs: tickets 04 and 05).
Boot arguments are not set here; they go on the mkdepthcharge command line (ticket 08).

scripts/check.sh checks offline that every CONFIG_ line and every "# require:" symbol exists in a804c57 Kconfig.
After the merge, the build fails unless all of them are =y.
Silent-boot channel 1: the failed boot's printk in depthcharge's ramoops region (defconfig: PSTORE_RAM=m).
require: SERIAL_QCOM_GENI
require: SERIAL_QCOM_GENI_CONSOLE
require: QCOM_GENI_SE
require: PINCTRL_MSM
require: PINCTRL_X1E80100
require: QCOM_PDC
require: COMMON_CLK_QCOM
require: CLK_X1E80100_GCC
require: QCOM_RPMH
require: QCOM_COMMAND_DB
require: QCOM_CLK_RPMH
require: QCOM_RPMHPD
require: INTERCONNECT
require: INTERCONNECT_QCOM
require: INTERCONNECT_QCOM_X1E80100
require: ARM_SMMU
require: ARM_SMMU_QCOM
require: ARM_PSCI_FW
require: ARM_PSCI_CPUIDLE
require: ARM_PSCI_CPUIDLE_DOMAIN
```

## [`mica-gpu.config`](mica-gpu.config)

```
Phase 3, GPU: the Adreno X1-85 (gpu@3d00000, qcom,adreno-43050c01) with its GMU (gmu@3d6a000).
Source: attempt 2026-11-03-4 (docs/recon/display-2026-11-03.md): 3da0000.iommu (the GPU SMMU) stayed deferred on
"supplier 3d90000.clock-controller not ready", and the display only bound because the command line carried
msm.skip_gpu=1. scripts/dt-kconfig-map.py on the mica-el2 DTB: gpucc is the one GPU-path driver still =m.
The command line now carries msm.separate_gpu_kms=1 instead (drivers/gpu/drm/msm/msm_drv.c:57-66,1082;
adreno_device.c:275), so the GPU gets its own DRM device and a GPU failure cannot take the display with it.
Firmware: qcom/gen70500_sqe.fw and qcom/gen70500_gmu.bin (a6xx_catalog.c:1573-1577), loaded on the first open of
the GPU's DRM device (msm_drv.c msm_open -> load_gpu), staged by scripts/stage-firmware.sh from
linux-firmware-qcom 20260916-1. The zap shader is disabled by x1-el2.dtso, so a6xx_gpu.c:1507-1516 writes
SECVID_TRUST_CNTL directly and warns "Zap shader not enabled".
The GPU clock controller (drivers/clk/qcom/Kconfig:278): GDSCs and clocks for the GPU, GMU and adreno_smmu.
require: DRM_MSM
require: ARM_SMMU
require: ARM_SMMU_QCOM
require: PM_DEVFREQ
require: DEVFREQ_GOV_SIMPLE_ONDEMAND
require: PM_OPP
require: QCOM_LLCC
```

## [`mica-pcie.config`](mica-pcie.config)

```
Phase 3, PCIe: bring up both PCIe controllers and enumerate their devices.
Source: every boot so far left pcie@1bf8000 and pcie@1c08000 deferred ("Failed to parse Root Port: -517");
scripts/dt-kconfig-map.py on the mica-el2 DTB shows their suppliers are =m in defconfig at a804c57.

Safety: the NVMe slot holds the stock SSD, which is never written (ADR 0003, ticket 07). BLK_DEV_NVME stays =m
(not loaded), so enumeration reads PCI config space only and no NVMe command reaches the SSD.
QMP PCIe PHYs: gen4x4 phy@1bfc000 (pcie@1bf8000) and gen3x2 phy@1c0e000 (pcie@1c08000). Their menu parent
PHY_QCOM_QMP is already =y in mica-usb.config.
forbid-y: BLK_DEV_NVME
require: PCIE_QCOM
require: PCIEPORTBUS
require: PCI_MSI
require: POWER_SEQUENCING
require: PCI_PWRCTRL
require: PCI_PWRCTRL_PWRSEQ
```

## [`mica-pmdebug.config`](mica-pmdebug.config)

```
Suspend debugging (2026-11-04, ADR 0009's suspend test): attempts 2026-11-04-5 to -8 reset the AP about 0.7 s after
the s2idle wake. With patch 0008 the PCIe GDSC warning is gone and the kernel prints nothing before the reset, so
/init (gbook.suspend=1) turns on /sys/power/pm_print_times and pm_debug_messages: every device's suspend and resume
callback is logged as "calling <cb> @ <pid>, parent: <dev>" before it runs (drivers/base/power/main.c:227-241 at
a804c57), and the last such line before the reset names the device. Both files exist only with PM_SLEEP_DEBUG
(kernel/power/main.c:644, a def_bool on PM_DEBUG && PM_SLEEP, kernel/power/Kconfig:257-259).
require: PM_SLEEP_DEBUG
```

## [`mica-rootfs.config`](mica-rootfs.config)

```
M3, the rootfs (ADR 0012, decision 6; .scratch/m3-rootfs ticket 01). systemd v262's README ("REQUIREMENTS") says
userspace firmware loading "is not supported and should be disabled in the kernel"; arm64 defconfig sets
FW_LOADER_USER_HELPER=y (built config, read 2026-11-04). Off here; firmware still loads from the filesystem
(Documentation/driver-api/firmware/fw_search_path.rst at a804c57). USB Attached SCSI for the rootfs stick: the stick
ran bulk-only so far (USB_UAS not set); UAS falls back to bulk-only for devices that lack it.
CONFIG_FW_LOADER_USER_HELPER is not set
forbid-y: FW_LOADER_USER_HELPER
```

## [`mica-scmi.config`](mica-scmi.config)

```
Phase 3, SCMI: CPU performance domains (cpufreq) through the CPUCP mailbox.
Source: every boot up to attempt 2026-11-03-7 left "firmware:scmi: supplier 17430000.mailbox not ready", then
"arm-scmi: failed to setup channels": the mailbox driver for qcom,x1e80100-cpucp-mbox
(drivers/mailbox/qcom-cpucp-mbox.c:205, Kconfig:343) is =m in defconfig, and the initramfs loads no modules.
The stock tree drives the same block: cpucp@18830000 (qcom,cpucp-v2) with reg 0x17430000 + 0x18830000, scmi mboxes
<cpucp 0 cpucp 2>, shmem at 0x18b4e000 (entry00-base.dts:384-402, :908-926, :10534-10540; stock also lists a vendor protocol@80 that hamoa.dtsi has not), as hamoa.dtsi does.
The CPUs take their "perf" power domain from scmi_dvfs (hamoa.dtsi:78-79 and the other cpu nodes).
require: MAILBOX
require: ARM_SCMI_PROTOCOL
require: ARM_SCMI_TRANSPORT_MAILBOX
require: ARM_SCMI_PERF_DOMAIN
require: ARM_SCMI_CPUFREQ
require: DEBUG_FS
```

## [`mica-sync.config`](mica-sync.config)

```
Phase 3, the last never-bound devices (handoff 2026-11-03 item 3; kernel/dt-gaps.txt "sync_state lead").
Source: attempt -26 left unbound=6: four bandwidth-monitor PMUs (pmu@24091000 qcom,sc7280-llcc-bwmon;
pmu@240b3400/@240b5400/@240b6400 qcom,sdm845-bwmon), videocc@aaf0000 and camcc@ade0000, all =m in defconfig while
the initramfs loads no modules (scripts/dt-kconfig-map.py at a804c57). An unbound interconnect consumer keeps the
providers from sync_state() and their boot-time votes in place (the crypto node did, Omarchy 2210); whether these
do is what the boot shows. Kconfig at a804c57: QCOM_ICC_BWMON drivers/soc/qcom/Kconfig:266 (selects PM_OPP,
REGMAP_MMIO), SM_VIDEOCC_8550 drivers/clk/qcom/Kconfig:1981 (covers X1E80100), CLK_X1E80100_CAMCC :247.
require: QCOM_ICC_BWMON
require: SM_VIDEOCC_8550
require: CLK_X1E80100_CAMCC
```

## [`mica-touch.config`](mica-touch.config)

```
Phase 3, touch: the I2C HID touchpad and touchscreen (owner 2026-11-03, after the retro's DT gap check).
Source: scripts/dt-kconfig-map.py --gaps listed "hid-over-i2c  I2C_HID_OF=m  touchscreen@10,touchpad@2c": the
OF glue for hid-over-i2c (drivers/hid/i2c-hid/Kconfig:25, selects I2C_HID_CORE) is =m in arm64 defconfig, and the
initramfs loads no modules, so neither node has ever bound. Nodes: touchpad@2c on i2c0 (descriptor 0x20, TLMM 3)
and touchscreen@10 (LG SW42101M, descriptor 0x0, TLMM 51) in dts/x1e80100-google-mica.dts.
HID_MULTITOUCH: a precision touchpad and a touchscreen report as multitouch; hid-generic would see a mouse at best.
require: I2C_HID
require: HID_GENERIC
require: INPUT_EVDEV
require: I2C_QCOM_GENI
```

## [`mica-tpm.config`](mica-tpm.config)

```
Phase 3, TPM: the Ti50 GSC's TPM on I2C (owner 2026-11-03, after the retro's DT gap check).
Source: scripts/dt-kconfig-map.py --gaps listed "google,cr50  TCG_TIS_I2C_CR50=m  tpm@50": the driver
(drivers/char/tpm/Kconfig:116) is =m in arm64 defconfig, so tpm@50 has never bound. It knows the Ti50 by its
DID/VID ("ti50 DT" / "ti50 OT", tpm_tis_i2c_cr50.c:693-702) and prints "<name> TPM 2.0 (i2c 0x50 irq N id 0x..)".
TPM traffic: probe sends startup/self-test and capability reads (tpm_chip_register); reboot sends
TPM2_Shutdown(CLEAR) (tpm-chip.c:272), as any Linux kernel with a TPM does. No NV or key writes.
require: TCG_TPM
require: HW_RANDOM_TPM
forbid-y: TCG_TPM2_HMAC
```

## [`mica-usb.config`](mica-usb.config)

```
Phase 3, USB: build the whole USB chain in, so the module-free initramfs can use it.
Merged after kernel/mica-firstboot.config by scripts/build-kernel.sh.
Source: the first boot (docs/recon/firstboot-2026-11-02.md): all four dwc3 controllers stayed deferred
("failed to register DWC3 Core") because every PHY, repeater, retimer and I2C driver below was =m in defconfig
at a804c57 and no module was loaded. Each line maps a compatible in x1e80100-google-mica-el2.dtb to its driver.
I2C buses that carry the PS8830 retimers and PTN3222 redrivers (qcom,geni-i2c).
require: USB_DWC3
require: USB_DWC3_QCOM
require: USB_XHCI_HCD
require: USB_XHCI_PLATFORM
require: USB_STORAGE
require: USB_HID
require: USB_ROLE_SWITCH
require: SPMI_MSM_PMIC_ARB
require: MFD_SPMI_PMIC
```

