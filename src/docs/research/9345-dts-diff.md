# mica vs the mainline XPS 13 9345 device tree

Compared 2026-10-21. Both trees were read on the build host; the device was not touched.

- **Mainline:** `arch/arm64/boot/dts/qcom/x1e80100-dell-xps13-9345.dts` with `hamoa.dtsi` and `hamoa-pmics.dtsi`,
  torvalds/linux `a804c5742bff224d4cb4d25dd383554d598be32b`.
- **Stock:** the base DTB and board overlay from recovery build 16471258 ([stock-dtb.md](stock-dtb.md), overlay 1
  sha256 `ae86b730…`).

Stock labels use Qualcomm's vendor names (`qupv3_seN_i2c`). Each was matched to its mainline label by **node
address** through the base DTB's `__symbols__` (for example `qupv3_se0_i2c` = `i2c@b80000` = mainline `&i2c0`).
GPIO numbers below are decimal; the stock overlay writes them in hex.

## Answer

**mica is a close derivative of the 9345 board.** The USB-C retimer block (both PS8830s, all six power-rail
GPIOs, both reset GPIOs), the touchscreen, the touchpad interrupt line, the PTN3222 reset, Wi-Fi enable, the
NVMe and Wi-Fi PCIe controllers, the eDP controller and the debug UART all match the 9345 exactly. The changes
cluster in a few places:

1. **ChromeOS parts replace Dell parts:** a cros-ec on SPI (keyboard, and probably lid and battery events), a
   Ti50 TPM on I2C, the AP firmware flash on QSPI, a USB fingerprint MCU.
2. **Touchpad moved:** it now sits on `i2c0`, where the 9345 has its I2C keyboard. The interrupt line is the
   same.
3. **Backlight is PWM** (PMK8550 PWM). The 9345's panel node has no PWM.
4. **eUSB2 repeaters:** two PTN3222 on `i2c5` (`0x4f`, `0x4b`) where the 9345 has one on `i2c9` (`0x4f`).
5. **Audio:** the WCD938x headset codec is disabled. Speakers use the WSA macros, plus 4 DMICs.

So the bring-up DTS should be **`#include` the 9345's board choices where they match, and replace the
keyboard, EC, backlight and repeater sections**. *Inference:* the 9345 DTS can be copied as the starting file,
not merely used as reference.

## AP console: `uart21`

| | 9345 mainline | mica stock |
|---|---|---|
| Alias | `serial0 = &uart21` | `serial0 = …/qcom,qup_uart@894000` (`qupv3_se21_2uart`, `qcom,geni-debug-uart`) |
| Address | `serial@894000` | `@894000` |
| Settings | | `stdout-path = "serial0:115200n8"` |

*Inference (strong):* the GSC's AP console (`ttyUSB1` on the build host, [ccd-gsc.md](ccd-gsc.md)) is wired to `uart21`.
A mainline kernel with `&uart21 { status = "okay"; }`, `stdout-path = "serial0:115200n8"` and `console=ttyMSM0,115200`
should print there. It is the first thing to check at first boot.

## Node by node

| Function | 9345 mainline | mica stock (mainline label) | Same? |
|---|---|---|---|
| Debug UART | `&uart21` | `&uart21` @ `894000` | yes |
| Bluetooth UART | `&uart14`, `qcom,wcn7850-bt`, bt-enable TLMM 116 | `&uart14` @ `a98000` (`msm-geni-serial-hs`), `bt_en` TLMM 116, `qcom,kiwi` | yes (WCN7850 = "kiwi") |
| Wi-Fi | `&pcie4`, `pci17cb,1107`, wlan-enable TLMM 117 | `pcie@1c08000` = `&pcie4`, `wlan-en-gpio` TLMM 117 | yes |
| NVMe | `&pcie6a` | `pcie@1bf8000` = `&pcie6a`, `qcom,no-l0s-supported` | yes; note no-L0s |
| Keyboard | `&i2c0` `keyboard@5` `hid-over-i2c`, int TLMM 67 | `cros-ec-keyb` under the EC, 8 rows x 18 columns | **no** |
| EC | Dell EC (not in this DTS) | `&spi13` `ec@0` `google,cros-ec-spi`, 3 MHz, int TLMM 66 | **no** |
| TPM | none | `&i2c10` `tpm@50` `google,cr50`, int TLMM 91 | **new** |
| AP flash | none | `&qspi` `flash@0` `jedec,spi-nor`, write-protect TLMM 19 | **new** |
| Touchpad | `&i2c17` `touchpad@2c`, int TLMM 3 | `&i2c0` `touchpad@2c`, `hid-descr-addr 0x20`, int TLMM 3, vdd PM "humu" L12, vddl TLMM 36 | **bus differs** |
| Touchscreen | `&i2c8` `touchscreen@10`, int TLMM 51 | `&i2c8` `touchscreen@10`, int TLMM 51, vdd "humu" L15 | yes (LG SW42101M) |
| Retimer 0 | `&i2c3` `typec-mux@8` `parade,ps8830`, reset PM8550 GPIO 10 | `&i2c3` `typec-mux@8` `parade,ps8830`, reset PM8550 GPIO 10 | yes |
| Retimer 1 | `&i2c7` `typec-mux@8`, reset TLMM 176 | `&i2c7` `typec-mux@8`, reset TLMM 176 | yes |
| Retimer rails | RTMR0: PMC8380-5 GPIO 8, PM8550VE-9 GPIO 8, PM8550 GPIO 11. RTMR1: TLMM 188, 175, 186 | identical (PMC8380 "F" = SID 5, PM8550VE "J" = SID 9) | yes |
| eUSB2 repeater | `&i2c9` `redriver@4f` `nxp,ptn3222`, reset TLMM 184 | `&i2c5` `redriver@4f` (reset TLMM 184) **and** `redriver@4b` (reset TLMM 10) | **bus differs, one extra** |
| USB-C ports | `usb_1_ss0/ss1` + `pmic_glink` connectors | `usb0/usb1` = `&usb_1_ss0/ss1`, role switch, retimers in the graph, UCSI connectors 0 and 1 | yes |
| USB multiport | `&usb_mp`, both HS and QMP PHYs on | `&usb_mp`, HS PHYs on, **QMP PHYs disabled**, fingerprint at port 2 (`usb18d1,5406`) | **partly** |
| Third USB controller | none | `usb4` = `&usb_2` (`a200000`) okay, HS PHY `&usb_2_hsphy` behind PTN3222 `0x4b` | **new** |
| Panel | `&mdss_dp3` eDP, `edp-panel` on aux-bus, enable TLMM 74 | `sde_edp` = `&mdss_dp3`, HPD TLMM 119 | yes, same controller |
| Backlight | no PWM in the panel node | PWM `pmk8550_pwm` channel 0, period 270000 ns; enable PMC8380-D GPIO 4, power PMC8380-D GPIO 10 | **no** |
| DP alt mode | `&mdss_dp0`, `&mdss_dp1` | `sde_dp`, `sde_dp1` = `&mdss_dp0/dp1` | yes |
| Speakers | WSA8845 via the WSA macros | `wsa_macro`, `wsa2_macro` tuned (`bat-cfgs`, `rloads`, gains) | likely same (both list 4x WSA8845) |
| Headset codec | (check the 9345 sound node) | WCD938x disabled, `qcom,wcd-disabled` | to compare |
| Mics | | DMIC0-3, `regulator-dmic-en` on TLMM 69 (stock overlay `entry01-overlay.dts` 1389: `EN_PP3300_MIC`, fixed, always-on; the base tree has none) | `dts/diag/sound.dtsi` carries it as the VA macro's `vdd-micb-supply` (2026-11-04, ticket 10); in the board DTS since 2026-11-05 |
| Charger PMICs | `&smb2360_0`, `&smb2360_1` | the same two; `smb2360_2/3` disabled | yes |
| GIC ITS | enabled | `gic_its` disabled, region reserved as `pkvm,protected-region` | stock pKVM detail; ignore for Linux at EL2 |
| Thermal | | `sys-therm-6` passive trip | port later |

Not compared yet: the camera (USB per coreboot, so probably UVC on `usb_mp` or `usb_2`), the ambient-light
sensor, the Glowbar, the lid switch, and the two fans. None of them appear in the board overlay. *Inference:* they
sit behind the EC or on USB.

## Plan for `dts/x1e80100-google-mica.dts`

Status 2026-10-21: done as a draft (`dts/x1e80100-google-mica.dts`, [ADR 0004](../adr/0004-device-tree-from-9345.md)). Two changes from this plan: the QSPI flash was left out because mainline hamoa has no QSPI node, and the touchpad reset is held by pinctrl because generic `hid-over-i2c` has no reset property. The `dts/README.md` table supersedes this list.

1. Copy `x1e80100-dell-xps13-9345.dts` at `a804c57`. Set `compatible = "google,mica", "qcom,x1e80100"` so
   depthcharge's FIT match (`google,mica…`) selects it, and set the model.
2. Keep the matching blocks: `uart21`, `uart14` with BT, `pcie4` with Wi-Fi, `pcie6a` with NVMe, both retimers and
   their rails, the touchscreen, `mdss_dp0/1/3`, `usb_1_ss0/ss1`, `smb2360_0/1`, the remoteprocs.
3. Replace:
   - `i2c0` keyboard → the touchpad (from `i2c17`);
   - drop the Dell EC;
   - add `&spi13 { cros_ec: ec@0 { compatible = "google,cros-ec-spi"; … } }` with `cros-ec-keyb` (keymap from
     overlays 1 and 2);
   - add `&i2c10 tpm@50 google,cr50`;
   - `i2c9` PTN3222 → `i2c5` at `0x4f` and `0x4b`, and enable `usb_2`;
   - backlight → `pwm-backlight` on the PMK8550 PWM.
4. Start minimal for the first boot: UART, NVMe or USB storage, simple-framebuffer if depthcharge leaves one
   (unknown), then add the rest.
5. Firmware names: the stock tree loads bare `adsp.mdt` and `cdsp.mdt` from `/vendor/firmware`. Mainline expects
   `qcom/x1e80100/<vendor>/<board>/…`; this needs a `qcom/x1e80100/google/mica/` path and the blobs pulled from
   `vendor` in `super`.

## Caveats

- The stock tree is a vendor tree. Only addresses, GPIOs, I2C addresses and regulators carry over. Property
  names (`qcom,…`) generally do not.
- `parade,ps8830` appears in the stock DT while coreboot selects `MAINBOARD_HAS_PS8820_RETIMER`. The Linux
  driver binding may cover both. Check `drivers/usb/typec/mux/ps883x.c` before the first USB-C test.
- The 9345 mainline DTS was read at one commit. Recheck against the tag the kernel is built from.
