# Console-only kernel config and boot arguments for the first mica boot

Researched 2026-10-21 for ticket 04. Sources
were read on the build host. Nothing was built, and the Googlebook was not touched. Items marked *inference* are reasoned from
source, not tested.

## Answer

**Derive the config with plain `make defconfig`.** Do not trim it. At torvalds `a804c57` the arm64 `defconfig`
already builds in every driver on `uart21`'s supplier chain. An arm64 defconfig `Image` is about 50 MiB, so the
256 MiB `KERNEL_SIZE` gives no reason to trim. After `make defconfig`, check the list below in `.config` before
building, so that a later tree or fragment cannot quietly switch one of them to `=m`.

**Must be `=y` (built in).** These are needed for `ttyMSM0` on `uart21` with no initramfs and no module loading:

| Option(s) | What needs it | Kconfig default | `defconfig` @ `a804c57` |
|---|---|---|---|
| `SERIAL_QCOM_GENI`, `SERIAL_QCOM_GENI_CONSOLE` | the `qcom,geni-debug-uart` driver, the `ttyMSM` console and the `qcom_geni` earlycon | none | `=y` (:585-586) |
| `QCOM_GENI_SE` | the `qupv3_2` wrapper (`qcom,geni-se-qup`); it creates the `uart21` child only once it probes | `ARCH_QCOM` | not in the file, so default `y` |
| `PINCTRL_MSM`, `PINCTRL_X1E80100` | TLMM: `qup_uart21_default` (gpio86/87, `qup2_se5`) | `ARCH_QCOM` | not in the file, so default `y` |
| `QCOM_PDC` | TLMM's `wakeup-parent = <&pdc>`; TLMM probe defers until PDC exists | none | `=y` (:1746) |
| `COMMON_CLK_QCOM`, `CLK_X1E80100_GCC` | `GCC_QUPV3_WRAP2_S5_CLK` ("se") and the wrapper's `m-ahb`/`s-ahb` clocks | GCC: `ARCH_QCOM` | `=y` (:1472, :1487) |
| `QCOM_RPMH`, `QCOM_COMMAND_DB`, `QCOM_CLK_RPMH`, `QCOM_RPMHPD` | `rpmhpd` CX powers both GCC and `uart21`, and the UART's OPP table requires rpmhpd levels. `rpmhcc` and the BCM voter sit under `apps_rsc` | RPMHPD: none | `=y` (:1660, :1654, :1496, :1678) |
| `INTERCONNECT`, `INTERCONNECT_QCOM`, `INTERCONNECT_QCOM_X1E80100` | the `qup-core`/`qup-config` paths on `clk_virt`, `gem_noc` and `config_noc` | none | `=y` (:1865, :1871, :1901) |
| `ARM_SMMU` (+ `ARM_SMMU_QCOM`, `def_tristate y`) | `iommus = <&apps_smmu 0x423 0x0>` on `qupv3_2` | none | `=y` (:1617) |
| `ARM_PSCI_FW` (selected by arm64), `ARM_PSCI_CPUIDLE`, `ARM_PSCI_CPUIDLE_DOMAIN` | `apps_rsc` has `power-domains = <&system_pd>`, a PSCI domain. Without its provider, RPMh never probes, and nothing downstream does either | DOMAIN: `y` | `ARM_PSCI_CPUIDLE=y` (:95); DOMAIN by default |

Three entries are missing from the `defconfig` *file* only because their Kconfig default (`ARCH_QCOM`) already makes
them `y`: `PINCTRL_MSM`, `PINCTRL_X1E80100` and `QCOM_GENI_SE`. Do not "fix" the file by adding them. No firmware
file is needed. coreboot loads the UART protocol into QUP2 SE5, and the kernel loads GENI firmware only when the
SE reports no protocol.

**Boot arguments** (they go into the `vbutil_kernel --config` command line, which depthcharge writes to
`/chosen/bootargs`. `defconfig` sets no `CONFIG_CMDLINE`):

```
console=ttyMSM0,115200n8 earlycon=qcom_geni,0x894000 clk_ignore_unused pd_ignore_unused
```

Optional for the first attempt: `ignore_loglevel`, and `keep_bootcon` (it keeps earlycon after `ttyMSM0` takes
over, so lines print twice). `root=` and `init=` belong to the FIT/initramfs tickets.

- **Use the explicit `earlycon=qcom_geni,0x894000`.** A bare `earlycon` reads `/chosen/stdout-path`, and
  `dts/x1e80100-google-mica.dts` has no `/chosen` node yet. `hamoa.dtsi:34` is `chosen { };`, and the 9345 file
  sets none either. ADR 0006 records `stdout-path = "serial0:115200n8"` as decided, so the DTS needs that line.
  That is a DTS-ticket item; this note does not edit the DTS.
  *Update 2026-10-21:* the DTS now sets `stdout-path = "serial0:115200n8"` (commit `709212e`).
- **Earlycon does not wait for clocks.** It registers from `early_param` before any driver probes, and its setup
  writes only SE registers. It sets no clock, pinmux, interconnect, OPP or baud rate. So it prints only if
  firmware left SE5 clocked, loaded with UART firmware, pinmuxed and running at 115200. coreboot always loads the
  UART firmware, but it sets the baud divider and pinmux only when its own serial console is built in. Whether
  mica's production firmware does that is not known (see "Not found").
- **`ttyMSM0` does not depend on firmware state.** The real console sets its own clocks, pins and 115200 baud when
  it probes. That happens once the chain above is up, and printk then replays the log buffer.
- **`clk_ignore_unused pd_ignore_unused`**: the stock Googlebook kernel boots with both, and so does Ubuntu
  Concept's x1e GRUB config. They are not needed for `ttyMSM0` itself, because the driver claims its clocks when
  it probes. They matter in the failure case: if the real driver never probes, `clk_disable_unused` would gate
  the QUP clocks at `late_initcall_sync` (they carry no `CLK_IGNORE_UNUSED`) and silence the earlycon (*inference*).

**Image size against `KERNEL_SIZE`.** KernelCI's arm64 `defconfig` build of mainline `b88c841d` (v7.3-rc6+,
clang-21, 2026-10-11) gives:
- `Image`: 52,271,616 bytes (49.9 MiB);
- header `image_size`: 53,084,160 bytes (50.6 MiB);
- `Image.gz`: 14.6 MiB.

depthcharge's kernel buffer is `KERNEL_SIZE` = 256 MiB. It holds the whole loaded body: the FIT with its kernel,
DTB and any ramdisk. An uncompressed `Image` uses about a fifth of it. That build is close to `a804c57`, not
`a804c57` itself.

**Other trees, as facts for the kernel-tree decision:**

| Tree, pin | Config used | GENI serial | Rest of the console chain | Notable differences |
|---|---|---|---|---|
| jhovold `wip/x1e80100-6.16` @ `a9cd6cda` (2025-07-28) | `arch/arm64/configs/johan_defconfig`, 429 lines | `=y`, console `=y` | all `=y` | Qualcomm-only, a trimmed defconfig. No ACPI, NVMe `=m`, `PCIE_QCOM=m`, DRM `=m`. Newest x1e branch on GitHub; repo last pushed 2025-09-19 |
| jglathe `jg/ubuntu-qcom-x1e-7.3.y` @ `0151068a` (2026-10-20) | Ubuntu packaging, `debian.qcom-x1e/config/annotations` | **`=m`**, console `=y` | all `=y` | Ubuntu distro config: ACPI, `EFI_ZBOOT`, `CMDLINE="console=ttyAMA0"`, NVMe `=m`, `CROS_EC_SPI=m`, `TCG_TIS_I2C_CR50=m` |
| Ubuntu Concept `linux-qcom-x1e` 7.0.0-22.22, `qcom-x1e-7.0` @ `d997b73b` (2026-03-26) | `debian.qcom-x1e/config/annotations` (flavour `arm64-qcom-x1e`) | **`=m`**, console `=y` | all `=y` | ACPI, `EFI_ZBOOT`, NVMe `=m`, `PCIE_QCOM=y`, `PHY_QCOM_QMP_PCIE=y`. Its `resolute-x1e` branch uses the generic Ubuntu config, where GCC, x1e TLMM and x1e interconnect are `=m` |

Both Ubuntu-based configs load the GENI serial driver from an initramfs. So a first boot without an initramfs would
print nothing on `ttyMSM0` from them, and earlycon would be missing too (*inference*). For a console-only first
boot, use `defconfig` or `johan_defconfig`, or add `SERIAL_QCOM_GENI=y` to one of the Ubuntu configs.

## Sources and revisions

| Source | Ref | Commit |
|---|---|---|
| torvalds/linux | master | `a804c5742bff224d4cb4d25dd383554d598be32b` (Makefile reads 7.3.0) |
| depthcharge | `firmware-bluey-16702.B` | `694eabf646855067acd51935059c3191436ccc79` |
| ChromiumOS coreboot | `firmware-bluey-16702.B` | `ff3258d575b0ddf4ba0514a2cd03c6a1936dba69` |
| jhovold/linux (GitHub) | `wip/x1e80100-6.16` | `a9cd6cda46ab81b1ec1d687d40ff0933dc6e6915` |
| jglathe/linux_ms_dev_kit (GitHub) | `jg/ubuntu-qcom-x1e-7.3.y` | `0151068ae447fd8f687b57837dd4be857cff7ca8` |
| Launchpad `~ubuntu-concept/ubuntu/+source/linux/+git/resolute` | `qcom-x1e-7.0` | `d997b73be317eed5dd6e617028769fb48addc3db` |
| same repo | `resolute-x1e` | `ba0042b4d0be94e27274fc336655f21fa0146027` |
| Launchpad `~ubuntu-concept/ubuntu/+source/ubuntu-x1e-settings` | default HEAD / `ubuntu/resolute` | `c38933d09985f3eae7f8f3982ac9d666fee101a2` / `d40028294dfd621a701e67ff79aff7df011b7e79` |
| KernelCI | kbuild node `6acbaef4a3f195e1aa6556c8` | mainline `b88c841d11641923fa3a4da011d7202cd89df68a` |

The kernel files came from `raw.githubusercontent.com/torvalds/linux/<commit>/…`, because the local sparse
checkout holds only DTS and bindings. The Ubuntu trees were read from shallow sparse clones. Paths below without a
repo prefix are in torvalds/linux at `a804c57`.

## Evidence

### 1. The probe chain from `uart21` to its suppliers (DT)

- `uart21: serial@894000` (`hamoa.dtsi:1296-1318`):
  - `clocks = <&gcc GCC_QUPV3_WRAP2_S5_CLK>`;
  - `interconnects` on `clk_virt` (`MASTER_QUP_CORE_2`), `gem_noc` and `config_noc` (`SLAVE_QUP_2`);
  - `power-domains = <&rpmhpd RPMHPD_CX>` and `operating-points-v2 = <&qup_opp_table_100mhz>`, whose OPPs require
    `rpmhpd_opp_low_svs`/`svs` (`:671-681`);
  - `pinctrl-0 = <&qup_uart21_default>`: gpio86 TX and gpio87 RX, function `qup2_se5` (`:6726-6737`).
- mica sets `compatible = "qcom,geni-debug-uart"` and `serial0 = &uart21`
  (`dts/x1e80100-google-mica.dts:32,1552-1555`). That is the same as the 9345, CRD and devkit.
- The parent `qupv3_2: geniqup@8c0000` (`hamoa.dtsi:847-862`) has the clocks `GCC_QUPV3_WRAP_2_M_AHB_CLK`
  and `_S_AHB_CLK`, and `iommus = <&apps_smmu 0x423 0x0>`.
- `gcc` (`:759-807`) has `power-domains = <&rpmhpd RPMHPD_CX>` (`:804`).
- `apps_rsc: rsc@17500000` (`:8575-8607`) has `power-domains = <&system_pd>` (`:8591`). Its children are
  `apps_bcm_voter`, `rpmhcc` and `rpmhpd`.
- `system_pd` is a child of `psci { compatible = "arm,psci-1.0"; }` (`:377-474`).
- `cmd-db` is a reserved-memory node (`:517-518`).
- `tlmm` (`:6095-6108`) has `wakeup-parent = <&pdc>`.

Code that turns these links into hard dependencies:
- The wrapper probe gets its clocks, then `devm_of_platform_populate()`. The UART child exists only after that
  (`drivers/soc/qcom/qcom-geni-se.c:1603-1650`).
- `geni_se_resources_init()` gets the `se` clock, the OPP table and the interconnect paths
  (`qcom-geni-se.c:1196-1226`, `geni_icc_get` at `:1220`). The serial probe calls it through `resources_init`
  (`drivers/tty/serial/qcom_geni_serial.c:1921`).
- TLMM returns `-EPROBE_DEFER` while the PDC wakeup domain is missing (`drivers/pinctrl/qcom/pinctrl-msm.c:1471-1477`).
- A missing PM-domain provider sends genpd to `driver_deferred_probe_check_state()`
  (`drivers/pmdomain/core.c:3362-3383`). That defers, then returns `-ETIMEDOUT` once `deferred_probe_timeout`
  expires (`drivers/base/dd.c:285-298`). The default is 10 s when `MODULES=y` (`drivers/base/Kconfig:76-79`).
  rpmh-rsc uses `pdev->dev.pm_domain` (`drivers/soc/qcom/rpmh-rsc.c:1124-1128`). So without the PSCI domain
  driver, `apps_rsc` never probes. The domain driver matches `arm,psci-1.0` and registers at `core_initcall`
  (`drivers/cpuidle/cpuidle-psci-domain.c:126,192`).
- Init order when everything is built in: the RPMh core and the x1e interconnect at `core_initcall`
  (`rpmh-rsc.c:1177`, `drivers/interconnect/qcom/x1e80100.c:1915`), TLMM at `arch_initcall`
  (`pinctrl-x1e80100.c:1866`), GCC at `subsys_initcall` (`gcc-x1e80100.c:7506`), and the GENI wrapper as a module
  init (`qcom-geni-se.c:1689`).
- *Inference:* `QCOM_SCM` (selected by `PINCTRL_MSM` and `ARM_SMMU_QCOM`), AOSS QMP and IPCC are not on this chain.

### 2. Kconfig and `defconfig`

- `SERIAL_QCOM_GENI` is a tristate that depends on `QCOM_GENI_SE`. `SERIAL_QCOM_GENI_CONSOLE` is a bool that
  selects `SERIAL_EARLYCON` (`drivers/tty/serial/Kconfig:915-929`).
- The `qcom,geni-debug-uart` match entry exists only with the console option (`qcom_geni_serial.c:2191-2199`).
- The earlycon is `OF_EARLYCON_DECLARE(qcom_geni, "qcom,geni-debug-uart", …)` (`:1755-1756`).
- *Inference:* with the driver `=m`, the earlycon table entry sits in the module and is never seen at early boot.
- Defaults:
  - `QCOM_GENI_SE`, `QCOM_COMMAND_DB` and `QCOM_RPMH`: `default ARCH_QCOM` (`drivers/soc/qcom/Kconfig:30-43,155-158`).
  - `PINCTRL_MSM`: `default ARCH_QCOM`. The SoC drivers sit inside `if PINCTRL_MSM`, and `PINCTRL_X1E80100` has
    `default ARCH_QCOM` (`drivers/pinctrl/qcom/Kconfig:2-17`, `Kconfig.msm:2,582-591`).
  - `CLK_X1E80100_GCC` and `QCOM_CLK_RPMH`: `default ARCH_QCOM` (`drivers/clk/qcom/Kconfig:267-276,416-419`).
  - `QCOM_RPMHPD` has no default (`drivers/pmdomain/qcom/Kconfig:20-26`). Neither does `INTERCONNECT_QCOM_X1E80100`
    (`drivers/interconnect/qcom/Kconfig:461-469`), `ARM_SMMU` (`drivers/iommu/arm/Kconfig:3-15`) or `QCOM_PDC`
    (`drivers/irqchip/Kconfig:523-529`).
  - `ARM_SMMU_QCOM` is `def_tristate y` and depends on `ARCH_QCOM` (`drivers/iommu/arm/Kconfig:53-59`).
  - `ARM_PSCI_FW` is selected by `ARM64` (`arch/arm64/Kconfig:110`). `ARM_PSCI_CPUIDLE_DOMAIN` is a bool with
    `default y` (`drivers/cpuidle/Kconfig.arm:17-44`).
- `arch/arm64/configs/defconfig` sets: `ARCH_QCOM=y` :69, `ARM_PSCI_CPUIDLE=y` :95, `MODULES=y` :127,
  `SERIAL_QCOM_GENI(_CONSOLE)=y` :585-586, `COMMON_CLK_QCOM=y` :1472, `CLK_X1E80100_GCC=y` :1487,
  `QCOM_CLK_RPMH=y` :1496, `ARM_SMMU=y` :1617, `QCOM_COMMAND_DB/GENI_SE=y` :1654-1655, `QCOM_RPMH=y` :1660,
  `QCOM_RPMHPD=y` :1678, `QCOM_PDC=y` :1746, `INTERCONNECT(_QCOM)=y` :1865/:1871, `INTERCONNECT_QCOM_X1E80100=y`
  :1901. It has no `CONFIG_CMDLINE` line.
- Also in `defconfig`, outside the console chain: `CROS_EC=y` and `CROS_EC_SPI=y` :1427-1430,
  `TCG_TIS_I2C_CR50=m` :611, `BLK_DEV_NVME=m` :309, `PSTORE_RAM=m` :1928. `PSTORE_RAM` matters for the ramoops
  fallback in ADR 0006, which the observation ticket covers.

### 3. Earlycon and console mechanics

- `earlycon=` with no options takes the console from `stdout-path`. `qcom_geni,<addr>` starts a polled console;
  "the serial port must already be setup and configured. Options are not yet supported"
  (`Documentation/admin-guide/kernel-parameters.txt:1398-1402,1515-1518`).
- Parsing:
  - `setup_earlycon()` tries names with an empty compatible first, then `qcom_geni` (`drivers/tty/serial/earlycon.c:176-214`).
  - `0x<addr>` parses as MMIO (`drivers/tty/serial/serial_core.c:2175-2176`).
  - The register page goes through the fixmap (`earlycon.c:39-48`; `FIX_EARLYCON_MEM` is `def_bool y`,
    `arch/arm64/Kconfig:364-365`).
  - The parameter is an `early_param` (`earlycon.c:242`).
- A bare `earlycon` on a DT boot with ACPI support goes through `early_init_dt_scan_chosen_stdout()`. That returns
  `-ENOENT` without `stdout-path` (`earlycon.c:223-241`, `arch/arm64/kernel/acpi.c:231-233`,
  `drivers/of/fdt.c:950-969`). arm64 selects `ACPI_SPCR_TABLE` when ACPI is on (`arch/arm64/Kconfig:12`), and
  `defconfig` has `ACPI=y` (:116).
- `qcom_geni_serial_earlycon_setup()` (`qcom_geni_serial.c:1702-1754`):
  - It returns `-ENXIO` unless the SE already reports the UART protocol.
  - It writes only packing, FIFO and frame registers in the SE. It touches no clock, pinctrl, ICC or baud divider.
- The real console:
  - It is named `ttyMSM`, and its index comes from the `serial` alias (`:1768-1787`, `:1895-1897`).
  - Only index 0 is valid (`GENI_UART_CONS_PORTS 1` at `:88`, check at `:1615`).
  - Setup defaults to 115200 and parses `console=` options (`:1605-1649`).
- If the SE has no protocol, the driver tries `geni_load_se_firmware()` (`:1358-1367`). That needs a
  `firmware-name` property on the wrapper (`qcom-geni-se.c:1565-1567`), which `hamoa.dtsi` does not set.
- Boot consoles are dropped when the preferred real console registers, unless `keep_bootcon`
  (`kernel/printk/printk.c:3868-3878,4211-4220`).

### 4. What firmware leaves on SE5 (coreboot `ff3258d`)

- `UART_FOR_CONSOLE` defaults to 21 (`src/soc/qualcomm/x1p42100/Kconfig:80-82`). That is QUP2 SE5, the same
  engine as Linux `uart21`.
- `load_qc_se_firmware_late()` loads UART firmware into `QUPV3_2_SE5` "even if coreboot's serial output is
  disabled" when `CONSOLE_SERIAL` is off (`src/mainboard/google/bluey/mainboard.c:290-297`). It runs from
  `mainboard_late_init` (`:320-322`).
- `qupv3_se_fw_load_and_init()` loads the firmware and sets up the SE (`src/soc/qualcomm/common/qupv3_config.c:14-80`).
- The baud divider (from XO), the TX/RX pinmux and the watermarks are set only in `uart_init()`
  (`src/soc/qualcomm/common/qupv3_uart.c:47-90`). That is coreboot's serial-console path.
- `qupv3_fw_init()` turns on all QUP clocks (`qupv3_config.c:255-262`). Where bluey calls it was not traced.

*Inference:* with production firmware (serial console presumably off), the SE reports UART, so earlycon
registers. Whether its output appears at 115200 depends on divider and pinmux state that coreboot does not set. The
real `ttyMSM0` console does not depend on any of this.

### 5. `clk_ignore_unused` and `pd_ignore_unused`

- Both are documented as debug/development aids that "should not be needed on a platform with proper driver
  support" (`kernel-parameters.txt:788-798,5279-5283`).
- Their code: `clk_disable_unused()` runs at `late_initcall_sync` (`drivers/clk/clk.c:1580-1627`), and
  `genpd_power_off_unused()` also at `late_initcall_sync` (`drivers/pmdomain/core.c:1356-1387`).
- The QUP clocks have no `CLK_IGNORE_UNUSED`. `gcc_qupv3_wrap2_s5_clk` has only `CLK_SET_RATE_PARENT`
  (`gcc-x1e80100.c:4900-4912`). The wrapper AHB clocks are at `:5014-5035`.
- Who passes them:
  - **Stock Googlebook kernel:** its live `/proc/cmdline` contains `clk_ignore_unused pd_ignore_unused`
    ([recon](../recon/recon-2026-10-21.md), `/proc/cmdline` row).
  - **Ubuntu Concept x1e:** `grub.d/ubuntu-x1e-settings.cfg` sets
    `GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX} clk_ignore_unused pd_ignore_unused cma=128M efi=noruntime"`, both at
    `c38933d0` and on `ubuntu/resolute` @ `d4002829`. The resolute copy also sets `GRUB_BADRAM`. The repo log has
    "Add efi=noruntime as recommended by jhovold" (2025-08-12).
  - *Inference:* `efi=noruntime` and the `GRUB_BADRAM` workaround are for UEFI boots, so they do not apply to a
    depthcharge DT boot.

### 6. Image size and depthcharge limits

- `config.mica`: `KERNEL_START=0xC7800000`, `KERNEL_SIZE=0x10000000`, `KERNEL_FIT_FDT_ADDR=0xDA800000`,
  `BASE_ADDRESS=0xDB000000`.
- The ldscript defines `_kernel_end = CONFIG_KERNEL_START + CONFIG_KERNEL_SIZE`
  (`src/image/depthcharge.ldscript.S:38-39`).
- vboot loads into `kernel_buffer = _kernel_start`, size `_kernel_end - _kernel_start` (`src/vboot/stages.c:161-162`).
  So 256 MiB bounds the loaded partition body.
- `boot_arm_linux()` reads the arm64 header and needs a contiguous free range of header `image_size` bytes. It
  picks a KASLR slot outside `[min(BASE_ADDRESS, KERNEL_START, FDT_ADDR), 4 GiB)` and reserved memory, then
  decompresses into it (`src/arch/arm/boot64.c:113-210`). The `Image` therefore runs from RAM above 4 GiB (or
  below `0xC7800000`), not from the 256 MiB buffer.
- FIT compression: none, lz4 or lzma ([chromeos-boot-path.md](chromeos-boot-path.md)).
- Measurement (2026-10-21): KernelCI node `6acbaef4a3f195e1aa6556c8`, `defconfig`, clang-21, artifact
  `files.kernelci.org/kbuild-clang-21-arm64-mainline-6acbaef4a3f195e1aa6556c8/Image.gz`, created 2026-10-11 11:44
  EDT [15:44 UTC]. Results:
  - `Image.gz`: 15,284,553 bytes;
  - `Image`: 52,271,616 bytes;
  - header `text_offset`: 0;
  - header `image_size`: 53,084,160;
  - magic `ARM\x64`.

### 7. Other trees

**jhovold:**
- `johan_defconfig` @ `a9cd6cda` sets:
  - `CPU_IDLE=y` :47, `ARM_PSCI_CPUIDLE=y` :48;
  - `SERIAL_QCOM_GENI(_CONSOLE)=y` :177-178, `PINCTRL_MSM/X1E80100=y` :188-190;
  - `COMMON_CLK_QCOM=y` :316, `QCOM_CLK_RPMH=y` :321, `ARM_SMMU=y` :335;
  - `QCOM_COMMAND_DB/GENI_SE/RPMH/RPMHPD/PDC=y` :348-363, `INTERCONNECT_QCOM_X1E80100=y` :381;
  - GCC by default;
  - `PCIE_QCOM=m` :115, `BLK_DEV_NVME=m` :129.
- It has no `ACPI` line, and `ACPI` defaults to `y` only on x86 (`drivers/acpi/Kconfig:9-17`).
- Branch head commits: "johan_defconfig: add custom config" and "arm64: defconfig: build Qualcomm PCIe driver as
  a module".
- GitHub API, 2026-10-21: the newest `wip/x1e80100-*` branch is 6.16 (head 2025-07-28), and the repo was last
  pushed 2025-09-19. kernel.org `johan/linux.git` only has `master` at 6.5-rc6.

**jglathe:**
- `debian/debian.env` is `DEBIAN=debian.qcom-x1e`, and `rebuild.sh` runs `dpkg-buildpackage`.
- `debian.qcom-x1e/config/annotations` sets:
  - `SERIAL_QCOM_GENI` `m` :10798, console `y` :10799;
  - `CLK_X1E80100_GCC` `y` :2359, `PINCTRL_MSM`/`X1E80100` `y` :8781/:8973;
  - `INTERCONNECT_QCOM_X1E80100` `y` :5729, `ARM_SMMU` `y` :1396, PSCI cpuidle `y` :1360-1361;
  - `QCOM_RPMH`/`RPMHPD` `y` :9297-9298, `QCOM_PDC` `y` :9280;
  - `EFI_ZBOOT` `y` :168, `CMDLINE` `"console=ttyAMA0"` :2384, `DEBUG_INFO_NONE` `y` :3171;
  - `BLK_DEV_NVME` `m` :51, `PCIE_QCOM` `y` :8421;
  - `CROS_EC_SPI` `m` :2859, `TCG_TIS_I2C_CR50` `m` :12233, `EC_QCOM_HAMOA` `n` :4046.
- Its dev-build `arch/arm64/configs/ubuntu_x1e_defconfig` (used by `devbuildconfig.sh`) also has
  `SERIAL_QCOM_GENI=m` :2290 and `CMDLINE="console=ttyAMA0"` :130.

**Ubuntu Concept:**
- `debian.qcom-x1e/config/annotations` @ `d997b73b` (header `FLAVOUR: arm64-qcom-x1e`) sets:
  - `SERIAL_QCOM_GENI` `m` :10416, console `y` :10417;
  - `CLK_X1E80100_GCC` `y` :2139, `PINCTRL_X1E80100` `y` :8625;
  - `INTERCONNECT_QCOM_X1E80100` `y` :5471, `ARM_SMMU` `y` :1203, PSCI cpuidle `y` :1169-1170;
  - `QCOM_RPMH`/`RPMHPD` `y` :8940-8941, `QCOM_PDC` `y` :8922;
  - `ACPI` `y` :502, `EFI_ZBOOT` `y` :156, `CMDLINE` `"console=ttyAMA0"` :2161;
  - `BLK_DEV_NVME` `m` :48, `PCIE_QCOM` `y` :8144, `PHY_QCOM_QMP_PCIE` `y` :8340.
- `resolute-x1e` @ `ba0042b4` builds from `debian.master` (generic arm64), where these are `m`:
  `CLK_X1E80100_GCC` :3033, `PINCTRL_X1E80100` :10897 and `INTERCONNECT_QCOM_X1E80100` :7167.
- With a `CONFIG_CMDLINE` set, the bootloader's command line still wins under the default
  `CMDLINE_FROM_BOOTLOADER` (*inference*, from Kconfig defaults; not read for this note).

## Not found

- **mica firmware serial state.** Whether mica's production coreboot is built with `CONSOLE_SERIAL` is unknown.
  So is whether depthcharge or anything after coreboot leaves SE5's divider, pinmux and clocks usable. Without
  that, nobody can say whether earlycon output will be readable at 115200. A read of `ttyUSB1` across a reboot
  answers it (silent-boot observation ticket). Where bluey calls `qupv3_fw_init()` was not traced.
- **No `stdout-path` in the mica DTS.** `dts/x1e80100-google-mica.dts` has no `/chosen/stdout-path`, although
  ADR 0006 decided `serial0:115200n8`. That belongs to a DTS change, not this ticket.
- **No `Image` built from `a804c57` itself.** The closest public measurement is `b88c841d` (v7.3-rc6+). A
  `defconfig` build of the chosen tree should record its own `Image` size.
- **No current jhovold x1e tree past 6.16** on GitHub or kernel.org as of 2026-10-21.
- **Launchpad cgit for the Ubuntu Concept kernel repos returns HTTP 403** for log/tree pages. Branch heads came
  from `code.launchpad.net` ref pages, and the configs from shallow clones.
- **Interconnect lookup when the x1e provider is a module.** `of_icc_get()`'s behaviour was not read; the
  "defers" claim in the table rests on the DT link plus `fw_devlink`, *inference*.
