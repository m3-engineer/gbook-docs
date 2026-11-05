# 4. Mainline device tree forked from the XPS 13 9345; stock tree as hardware map only

## Status

Accepted 2026-10-21.

## Context

- **No mica DTS exists anywhere:** not in mainline, not in the ChromiumOS 6.12 kernels, not on lore.
- **The stock DT is a Qualcomm vendor tree:** an LZ4 base plus overlays in `dtbo_a`, with `sde`, `qupv3_seN` and
  `qcom,…` properties. Mainline cannot boot it.
- **The 9345 is a close match:** address-by-address comparison ([9345-dts-diff.md](../research/9345-dts-diff.md))
  shows mica reuses its retimer block, touchscreen, PCIe, eDP and `uart21` debug console. The parts that differ
  are ChromeOS ones: cros-ec, Ti50, QSPI flash, a USB fingerprint MCU.

## Decision

- `dts/x1e80100-google-mica.dts` starts as an **unmodified copy** of mainline
  `x1e80100-dell-xps13-9345.dts` at a pinned commit (torvalds `a804c57`), committed alone. Mica's changes go in
  later commits, so the diff is the record.
- `compatible = "google,mica", "qcom,x1e80100"`.
- The stock tree is used **only** as a hardware map: buses, addresses, GPIOs, regulators, keymap. Every
  board-specific pin must trace to it. Anything copied from the 9345 without a stock match is marked
  "unverified".
- Checks before a commit counts: `scripts/build-dtb.sh` with no warnings, and `dt-validate` with no findings
  beyond the pending `google,mica` binding.

## Consequences

- Upstreaming later needs a `qcom.yaml` binding patch, alphabetical node order and correct attribution.
- Mainline changes to the 9345 file should be followed by re-basing onto a newer pinned commit.
- Missing pieces (keyboard backlight, Glowbar, ALS, fans, audio, camera) get added once something boots.

## Update 2026-10-21

- **EL2 changes come from mainline's `x1-el2.dtso`,** applied at build time (`x1e80100-google-mica-el2.dtb`), the
  way mainline builds every x1 board. The DTS stays the plain board file
  (What goes into the first-boot DTB).
- **One board fact traces to firmware source rather than the stock tree.** The framebuffer reservation's address
  matches the stock `splash_region` (`0xe4800000`). Its size, `0x2200000`, comes from coreboot's `memlayout.ld`;
  stock uses `0x21c0000` with no `no-map`.
- **`/chosen/stdout-path = "serial0:115200n8"`** is now in the DTS, traced to the stock base (commit `709212e`).
