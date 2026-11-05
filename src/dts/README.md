# dts

`x1e80100-google-mica.dts` is the mainline device tree for the Dell XPS Googlebook (`mica`). **Draft, never
booted** (2026-10-21). Booted since 2026-11-02; each feature's state is in [`docs/status.md`](../docs/status.md).

- **Experiments:** device-tree diagnostics go in `diag/` as `.dtsi` fragments, built on top with
  `GBOOK_DTS_EXTRA`, not into this file (2026-11-03).
- **Base:** forked from `arch/arm64/boot/dts/qcom/x1e80100-dell-xps13-9345.dts` at torvalds/linux
  `a804c5742bff224d4cb4d25dd383554d598be32b`. The first commit is the unmodified copy, so `git log -p` shows every
  mica change. The SoC dtsi at that pin is `hamoa.dtsi` (with `hamoa-pmics.dtsi`), not `x1e80100.dtsi`.
- **Board changes:** from the stock Googlebook OS tree ([stock-dtb.md](../docs/research/stock-dtb.md)), mapped to
  mainline labels in [9345-dts-diff.md](../docs/research/9345-dts-diff.md). The stock tree is two files:
  `dumps/recovery-16471258/dtbo/entry00-base.dts` (the SoC) and `entry01-overlay.dts` (the board: regulators, the
  sound card's overrides, thermal trips). Search both; a value "not in the stock tree" was found in the overlay on
  2026-11-04 (retro-12/01).
- **Compatible:** `"google,mica", "qcom,x1e80100"`, so depthcharge's FIT matcher (`google,mica-rev*-sku*` down to
  `google,mica`) picks it.

## Build and check

```bash
scripts/setup-toolchain.sh   # once: sparse kernel checkout at a804c57 + dtschema venv + schema, in ~/.cache/gbook
scripts/build-dtb.sh ~/.cache/gbook/linux-a804c57 dts/x1e80100-google-mica.dts /tmp/mica.dtb   # cpp + dtc, Kbuild W=0
~/.cache/gbook/venv-dtschema/bin/dt-validate -s ~/.cache/gbook/schema-a804c57.json /tmp/mica.dtb
# first-boot DTB: the same base plus the pinned x1-el2.dtbo, applied with fdtoverlay like Kbuild's -dtbs targets
scripts/build-dtb.sh ~/.cache/gbook/linux-a804c57 dts/x1e80100-google-mica.dts /tmp/mica-el2.dtb \
  ~/.cache/gbook/linux-a804c57/arch/arm64/boot/dts/qcom/x1-el2.dtso
```

`scripts/check.sh` builds and validates both DTBs, and also fails when the keymap drifts from stock. When the `google,mica` binding
lands, remove its allowance in `check.sh`.

State 2026-10-21:
- Build: no warnings.
- `dt-validate`: one finding. `google,mica` is not yet in `Documentation/devicetree/bindings/arm/qcom.yaml`;
  upstreaming needs that binding patch. The unmodified 9345 validates clean with the same schema.
- The keymap in the built DTB is identical to stock (119 entries).
- Every board-specific TLMM pin in the built DTB traces to the stock tree. A programmatic check compared the
  decompiled DTB with the stock overlay and base. The only other pins are SoC-level states from `hamoa.dtsi`
  (QUP UARTs, LPASS) and the PCIe clkreq pins the stock base also sets. No 9345-only pin survived.

## What changed from the 9345

| Area | Change | Evidence |
|---|---|---|
| Identity | model, compatible | depthcharge `fit.c` matching |
| Console | `/chosen/stdout-path = "serial0:115200n8"` (`serial0` = `uart21`), added 2026-10-21 | stock base `chosen`; [ADR 0006](../docs/adr/0006-debug-console-ccd-suzyq.md) |
| Keyboard, lid | removed the I2C keyboard (`i2c0` `0x5`), GPIO lid (92) and camera LED (110); added `cros_ec` on `spi13` (int TLMM 66, 3 MHz) with `cros-ec-keyb` 8x18 and the stock keymap; spi13 CS on gpio55 (stock pin) as `cs-gpios`, a mainline choice after trogdor/herobrine; the hardware CS gave garbage, the GPIO CS works (attempts 2026-11-03-13 and -14, [ec-2026-11-03.md](../docs/recon/ec-2026-11-03.md)) | stock overlay; no lid or LED GPIO in the stock tree |
| Touchpad | moved from `i2c17` to `i2c0` `0x2c`; int TLMM 3; reset TLMM 2 held high by pinctrl; vdd L12B, vddl a 3.3 V switch on TLMM 36 | stock overlay |
| Touchscreen | `hid-descr-addr` 0; vdd L15B, vddl a 3.3 V switch on TLMM 88 (150 ms startup); report-enable TLMM 89 low (replaces the 9345's TLMM 75) | stock overlay |
| SCMI | `arm,max-rx-timeout-ms = <1000>` on `/firmware/scmi` (250 on attempts -20 to -22), **unverified** diagnostic with no stock counterpart (2026-11-03: the default 30 ms failed on 5 of 7 cold starts) | [scmi-cpucp-timeouts.md](../docs/research/scmi-cpucp-timeouts.md), option 2 |
| CPU idle | **deviation from stock** ([ADR 0009](../docs/adr/0009-no-psci-cpuidle.md), superseding ADR 0008): `domain-idle-states` (`cluster_c4`) deleted from `cpu_pd0`-`11`, so cpuidle-psci does not load and cores idle in WFI; the cluster and system states stay as stock. A core in PSCI `ret` did not take a pending SPI until a PPI ran (SCMI stalls on whichever CPU the IRQ was routed to, 2026-11-04-3) | stock base has `cluster_c4` on every CPU; [scmi-2026-11-03.md](../docs/recon/scmi-2026-11-03.md) |
| Crypto engine | `&crypto` disabled, not from the stock tree: QCE is BROKEN at the pin, and the unbound node kept `aggre2_noc` and `mc_virt` from `sync_state()` (Omarchy `2210`, 2026-11-03) | `drivers/crypto/Kconfig:531` |
| TPM | `google,cr50` on `i2c10` `0x50`, int TLMM 91, `EDGE_FALLING` | stock overlay; `tpm_tis_i2c_cr50.c:751` requests `IRQF_TRIGGER_FALLING` at `a804c57` |
| eUSB2 repeaters | `i2c9` → `i2c5`; `0x4f` (reset 184) and new `0x4b` (reset TLMM 10) for `usb_2` | stock overlay |
| USB | `usb_2` host plus `usb_2_hsphy` | stock overlay (`usb4`, `usb2_phy_4`) |
| Backlight | `pwm-backlight`: `pmk8550_pwm` channel 0, 270000 ns; enable PMC8380-3 GPIO 4; supply switch PMC8380-3 GPIO 10. Panel enable TLMM 74 removed. 2026-11-03: the `edp_bl_en` pin state moved from TLMM 74 (left over from the 9345) to PMC8380-3 GPIO 4; the PWM pin (PMK8550 GPIO 5) takes the stock `edp_pwm_active` config | stock overlay (`sde_edp` `qcom,edp-backlight-en-gpio`, fragment 76 `edp_pwm_active`); same wiring as mainline T14s |
| Always-on rails | camera 3.3 V (TLMM 206), fingerprint MCU (TLMM 22) | stock overlay |
| Reserved GPIOs | union of stock `<34 2> <44 4>` and the 9345's `<76 4> <238 1>` | stock base `gpio-reserved-ranges` |
| EL2 overlay | `x1-el2.dtso` applied, then `dts/mica-el2.fixups` deletes `iommus` from `remoteproc_adsp` and `remoteproc_cdsp` (2026-11-02) | stock base `entry00-base.dts:5513`, `:12925` have none; with it, mica's TrustZone refuses the PAS resource-table call (`-EIO`) |
| Audio | added 2026-11-05 (from `dts/diag/sound.dtsi`, booted as a TEST IMAGE 2026-11-04-26 to 2026-11-05-6; the moved node proven on the base image `bc62c69e…`, attempt 2026-11-05-5, 3 clean cold boots, the four names heard on each, released as `v2026.11.05`): `sound` (`qcom,x1e80100-sndcard`, model `X1E80100-Dell-XPS-13-9345`), 4x WSA8845 on `swr0` and `swr3` (`speaker@0,0`/`@0,1` per bus, reset TLMM 204 for `swr0`'s pair, 205 for `swr3`'s, `vdd-1p8` L15B), 4 DMICs on `lpass_vamacro` (LPI 6/7, 8/9; capture heard 2026-11-05), the mic rail `EN_PP3300_MIC` (TLMM 69, fixed, always-on) as `vdd-micb-supply`; pin states `dmic_pp3300_en`, `spkr_02_sd_n_active`, `spkr_13_sd_n_active`. Modelled on the Yoga Slim 7x at `a804c57`. **Deviation:** stock's active state drives the shutdown pins high, the pin states here start them low (the Yoga's way, the codec driver's `reset-gpios` releases them); all four units enumerate and play that way (ticket 16) | stock base `entry00-base.dts`: card 17905 (routing 17921, dmic pins 17925), `wsa_swr_master` 17641 (codecs 17658, 17675; pins 16697, 16760; shutdown 18214 = TLMM 204, 5080), `wsa2_swr_master` (pins 17049, 17112; shutdown 18222 = TLMM 205, 5115), `pm_humu_l15` 10857, `va-macro@7660000` 17499; stock overlay `entry01-overlay.dts` 1389 (`regulator-dmic-en`), 1374 (`dmic_pp3300_pin`); [audio-2026-11-04.md](../docs/recon/audio-2026-11-04.md) |
| Firmware paths | `qcom/x1e80100/google/mica/…` | not in linux-firmware. 2026-11-02: ADSP and CDSP names changed to the stock split files `adsp.mdt`/`adsp_dtb.mdt` and `cdsp.mdt`/`cdsp_dtb.mdt`, read from the stock `modem_a` partition's `image/` (recovery stick copy, build `16560795`) |

Kept from the 9345 and confirmed in the stock tree: retimers and all six rail GPIOs; USB-C orientation GPIOs 121
and 123; eDP 3.3 V on TLMM 70 and HPD on 119; NVMe 3.3 V on TLMM 18; PCIe4 (146-148) and PCIe6a (152-154); Wi-Fi
3.3 V on TLMM 214, WLAN 117, BT 116; `uart14` BT; `uart21` debug.

## First-boot additions

Decided 2026-10-21 (What goes into the first-boot DTB),
in the tree since 2026-11-02:
- **`reserved-memory`:** `framebuffer@e4800000`, `reg = <0x0 0xe4800000 0x0 0x2200000>`, `no-map`. The address
  comes from the stock `splash_region`, the size from coreboot's reservation.
- **The first-boot DTB** is `x1e80100-google-mica-el2.dtb` = this DTB + `x1-el2.dtbo` from the pinned kernel.
  `scripts/build-dtb.sh` and `check.sh` build and validate both. 2026-11-02: both build with no warnings, both
  give only the `google,mica` `dt-validate` finding, and the `-el2` DTB keeps `compatible = "google,mica"`. The
  reservation overlaps no `hamoa.dtsi` region (nearest: `tags_mem1`, ending at `0xe36a0000`).

## Unverified (check at first boot)

- ~~The left/right labels on the USB-C connectors (copied from the 9345).~~ 2026-11-03: swapped on mica.
  `connector@0` (retimer on `i2c3`, `usb_1_ss0`, `mdss_dp0`) is the left port, `connector@1` (`i2c7`, `usb_1_ss1`,
  `mdss_dp1`) the right one ([dp-2026-11-03.md](../docs/recon/dp-2026-11-03.md)).
- `usb_2_hsphy` supplies (from other hamoa boards; the stock overlay does not set them).
- `usb_mp` QMP PHYs: stock disables both, and this draft keeps the 9345's enabled ones so `usb_mp` probes.
- The panel model (`edp-panel` probes it over AUX) and the PWM period.
- The `edp_bl_en` pin config on PMC8380-3 GPIO 4 (`function = "normal"`, from the T14s; stock has no pin state for it).
- Through the EC, no DT node needed (2026-11-03, attempt -14): keyboard backlight (`chromeos::kbd_backlight`), fan RPM (`cros_ec` hwmon).
- Audio (2026-11-05, moved from `dts/diag/sound.dtsi`): `vdd-io-supply` L12B on the four codecs (not in the stock codec nodes; every
  `a804c57` x1e80100 board uses it); `qcom,dmic-sample-rate = <4800000>` (the Yoga's; stock sets only the clock divider 16);
  the 3.3 V `EN_PP3300_MIC` as the VA macro's `vdd-micb-supply` (the Yoga's is a 1.8 V LDO; the stock rail is always-on, so a
  wrong consumer binding is harmless); which physical unit each prefix (`WooferLeft`, `TweeterLeft`, `WooferRight`,
  `TweeterRight`, the UCM profile's names) drives: stock calls `swr0`'s pair SpkrLeft/SpkrRight and `swr3`'s Spkr2Left/Spkr2Right.
  The speakers play (ticket 16, 2026-11-05). 9:26 AM EST 2026-11-05: capture passed (the owner heard the recording played back,
  [audio-2026-11-04.md](../docs/recon/audio-2026-11-04.md), "The capture test"), so the DMIC rate and the mic rail work as written;
  the values stay the Yoga's where stock has no counterpart, and the unit-to-prefix question stays open.
- Not described yet: EC PWM, Glowbar, ambient-light sensor (the 9345 file has no sound node at this commit; mica's is
  above), camera (USB), fingerprint (USB).

## Before sending upstream

- Add `google,mica` to `Documentation/devicetree/bindings/arm/qcom.yaml` (x1e80100 boards).
- Reorder the `&label` blocks alphabetically, as qcom reviewers expect. They are left in place here so the diff
  against the 9345 copy stays readable.
- Replace the copied 9345 copyright header with the right attribution for a derived file.

## Source files

[`x1e80100-google-mica.dts`](x1e80100-google-mica.dts) (the board DTS) and [`mica-el2.fixups`](mica-el2.fixups) (the
differences from mainline's `x1-el2.dtso`), as exported.
