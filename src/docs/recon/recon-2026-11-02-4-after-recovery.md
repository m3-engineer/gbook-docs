# Recon 2026-11-02

Collected 2026-11-02 20:11 EST by `scripts/recon.sh`: read-only, adb shell as uid 2000 over wireless debugging.
Serials, boot ids and MACs are redacted. `denied` and `absent` are findings about what the stock OS exposes.

| Item | Status | Value |
|---|---|---|
| `ro.product.device` | ok | mica |
| `ro.product.board` | empty |  |
| `ro.boot.hardware` | ok | android-desktop |
| `ro.bootloader` | ok | depthcharge-Google_Mica.16702.59.0/Google_Mica.16702.143.0 |
| `ro.boot.hwc` | empty |  |
| `ro.build.fingerprint` | ok | Dell/mica/mica:17/CL3B.260622.276.R2/16560795:user/release-keys |
| `ro.boot.verifiedbootstate` | ok | orange |
| `ro.boot.flash.locked` | ok | 0 |
| `ro.boot.vbmeta.device_state` | ok | unlocked |
| `ro.boot.slot_suffix` | ok | _a |
| `ro.boot.dtbo_idx` | ok | 0,1,2 |
| `ro.boot.hypervisor.protected_vm.supported` | ok | 1 |
| `kernel` | ok | Linux localhost 6.12.81-android16-6-g08dd7534bf44-ab16287118-4k #1 SMP PREEMPT Tue Sep  8 10:57:08 UTC 2026 aarch64 Toybox |
| `/proc/cmdline` | ok | console=ttynull stack_depot_disable=on cgroup_disable=pressure kasan.stacktrace=off kvm-arm.mode=protected bootconfig clk_ignore_unused pd_ignore_unused efi=noruntime efi=novamap android_arch_task_struct_size=512 id_aa64mmfr1.vh=0 arm64_sw.hvhe=0 irqaffinity=0-3 pcie_ports=compat cpufreq.default_governor=performance kvm-arm.ffa-unmap-on-lend=full,nr_handles=8192 kvm-arm.ffa_max_nr_constituents=16384 firmware_class.path=/vendor/firmware,/vendor/firmware_mnt/image console=null 8250.nr_uarts=4 console_msg_format=syslog log_buf_len=1M cgroup_disable=pressure root=/dev/ram0 reserve_mem=20M:2M:trace trace_instance=boot_mapped^traceoff@trace drm.trace=0x106 module_blacklist=cros_ec_debugfs proc_mem.force_override=ptrace binder.impl=rust no_console_suspend softlockup_panic=1 nmi_watchdog=panic pm.dpm_watchdog_enabled=1 cpufreq.default_governor=performance trace_instance=backup=boot_mapped cpuidle.governor=teo kvm-arm.protected_modules=qnoc-x1e80100.ko,pkvm-smc-filter.ko,rpmh-regulator.ko,clk-rpmh.ko,gcc-x1e80100.ko,gpucc-x1e80100.ko,pkvm-secure-memory-manager.ko,qcom_smmu_v2_v3_dispatcher.ko,pkvm_drng.ko bootconfig |
| `/proc/cpuinfo (head)` | ok | processor	: 0<br>BogoMIPS	: 38.40<br>Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma lrcpc dcpop sha3 sm3 sm4 asimddp sha512 asimdfhm dit uscat ilrcpc flagm ssbs sb paca pacg dcpodp flagm2 frint i8mm bf16 rng bti ecv afp rpres wfxt<br>CPU implementer	: 0x51<br>CPU architecture: 8<br>CPU variant	: 0x2<br>CPU part	: 0x001<br>CPU revision	: 1<br><br>processor	: 1<br>BogoMIPS	: 38.40<br>Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm jscvt fcma lrcpc dcpop sha3 sm3 sm4 asimddp sha512 asimdfhm dit uscat ilrcpc flagm ssbs sb paca pacg dcpodp flagm2 frint i8mm bf16 rng bti ecv afp rpres wfxt |
| `/sys/firmware` | ok | devicetree<br>fdt<br>log<br>vpd |
| `/proc/device-tree/model` | absent | cat: /proc/device-tree/model: No such file or directory |
| `/proc/device-tree/compatible` | denied | /system/bin/sh: can't open /proc/device-tree/compatible: Permission denied |
| `/sys/firmware/devicetree/base/compatible` | denied | /system/bin/sh: can't open /sys/firmware/devicetree/base/compatible: Permission denied |
| `/sys/firmware/devicetree/base (names)` | ok | #address-cells<br>#size-cells<br>__symbols__<br>aliases<br>chosen<br>cluster-device0<br>cluster-device1<br>cluster-device2<br>cluster-device3<br>compatible<br>cpus<br>firmware<br>fpmcu-vcc-regulator<br>interrupt-parent<br>lpddr-channel0<br>lpddr-channel1<br>lpddr-channel2<br>lpddr-channel3<br>lpddr-channel4<br>lpddr-channel5<br>lpddr-channel6<br>lpddr-channel7<br>memory<br>mmio-sram@18b4e000<br>name<br>pmu<br>psci<br>qcom,hdcp<br>regulator-dmic-en<br>regulator-pp3300-ucam<br>reserved-memory<br>rsc@af20000<br>soc<br>sram@c3f0000<br>sys-pm-vx@c320000<br>timer<br>touchpad-vdd-regulator<br>touchscreen-vdd-regulator<br>wlan-3p3-regulator |
| `/sys/firmware/fdt (bytes)` | denied | /system/bin/sh: can't open /sys/firmware/fdt: Permission denied |
| `/sys/firmware/log (bytes)` | denied | /system/bin/sh: can't open /sys/firmware/log: Permission denied |
| `partition names` | ok | KERN-A<br>KERN-B<br>ROOT-B<br>bluetooth_a<br>bluetooth_b<br>boot_a<br>boot_b<br>desktop_security_persist<br>desktop_security_storage<br>dsp_a<br>dsp_b<br>dtb_a<br>dtb_b<br>dtbo_a<br>dtbo_b<br>frp_persist<br>init_boot_a<br>init_boot_b<br>keymaster_a<br>keymaster_b<br>metadata<br>misc<br>modem_a<br>modem_b<br>nvme0n1<br>ota_recovery_a<br>ota_recovery_b<br>persist<br>pvmfw_a<br>pvmfw_b<br>rawdump<br>recovery_a<br>recovery_b<br>super<br>userdata<br>vbmeta_a<br>vbmeta_b<br>vendor_boot_a<br>vendor_boot_b |
| `firmware tools on PATH` | ok | crossystem: none<br>futility: none<br>gsctool: /system/bin/gsctool<br>ectool: /system/bin/ectool<br>vpd: none<br>flashrom: none |
| `GSC firmware (gsctool -a -f)` | ok | start<br>device: NT<br>keyids: RO 0xd4fd1f25, RW 0x405a3825<br>offsets: backup RO at 0, backup RW at 0x10000<br>Current versions:<br>RO 2.0.119<br>RW 0.33.291 |
| `CCD state (gsctool -a -I)` | ok | State: Locked<br>Password: None<br>Flags: 000000<br>Capabilities, current and default:<br>  UartGscRxAPTx         Y Always<br>  UartGscTxAPRx         Y Always<br>  UartGscRxECTx         Y Always<br>  UartGscTxECRx         - IfOpened<br>  UartGscRxFpmcuTx      Y Always<br>  UartGscTxFpmcuRx      - IfOpened<br>  FlashAP               - IfOpened<br>  FlashEC               - IfOpened<br>  OverrideWP            - IfOpened<br>  RebootECAP            - IfOpened<br>  GscFullConsole        - IfOpened<br>  UnlockNoReboot        Y Always<br>  UnlockNoShortPP       Y Always<br>  OpenNoTPMWipe         - IfOpened<br>  OpenNoLongPP          - IfOpened<br>  RemoveBatteryBypassPP Y Always<br>  I2C                   - IfOpened<br>  FlashRead             Y Always<br>  OpenNoDevMode         - IfOpened<br>  OpenFromUSB           - IfOpened<br>  OverrideBatt          - IfOpened<br>  AllowUnverifiedRo     - Never<br>CCD caps bitmap: 0x29817<br>Capabilities are default. |
| `EC version (ectool version)` | denied | Error: Permission denied (os error 13) |
