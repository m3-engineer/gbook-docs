# First boot of mainline Linux on mica (2026-11-02)

Redacted excerpt ([ADR 0005](../adr/0005-vendor-content-out-of-git.md)). Raw logs: `dumps/firstboot/2026-11-02-ap.log`
(AP console over SuzyQ) and `dumps/firstboot/2026-11-02-2-lastkmsg.txt` (dropbox `SYSTEM_LAST_KMSG` on the next stock
boot). Procedure: first-boot runbook. Attempt `2026-11-02-2`.

## Result: Gate 2 passes

From the ramoops readback (dropbox entry stamped 2026-11-02 20:19:42, Googlebook clock):

```
[    0.000000] Linux version 7.3.0-ga804c5742bff (the owner@the build host) (clang version 23.1.3, LLD 23.1.3) #1 SMP PREEMPT_DYNAMIC Mon Nov  2 17:04:02 EST 2026
[    0.000000] Machine model: Dell XPS Googlebook
[    0.039540] CPU: All CPU(s) started at EL2
[   61.158726] reboot: Restarting system
```

- **Image:** `mica-usb.img` sha256 `15a107e5…`, KERN-A on a USB 3 stick in the right port, booted with Boot from external
  drive. torvalds `a804c57`, `defconfig` + `kernel/mica-firstboot.config`, `x1e80100-google-mica-el2.dtb`.
- **Coreboot table:** `board-id` `00000003`; no `sku-id` and no `fw-config` node.
- **`/init`** ran to the end: every `GBOOK:` line printed, then `reboot -f` after 60 s. No panic, no oops.

## Channels

| Channel | Seen | Note |
|---|---|---|
| AP console (`-if01`, `ttyMSM0`) | yes, from 0.67 s | `earlycon: qcom_geni0 MMIO:0x894000` and the bootconsole registered, but nothing reached the SuzyQ before `ttyMSM0` probed. *Inference:* the firmware does not leave QUP2 SE5 set up for 115200 (ticket 04's open point), so the banner is not on the AP console |
| ramoops → dropbox | yes, full log | `ramoops: using 0x100000@0x86584000`; read on the next stock boot |
| Panel | `fb0` up | `simpledrm` bound `simple-framebuffer.0` from the coreboot table (no `DRM_COREBOOTDRM`, as expected) |
| EC console | power states only | warm reset at the reboot |

## For Phase 3 (from the same log)

- `arm-smmu 3da0000.iommu` probe fails with `-110`.
- USB (`a200000`, `a400000`, `a600000`, `a800000`): `dwc3-qcom` deferred, DWC3 core not registered.
- PCIe `1bf8000` and `1c08000`: root port parse deferred (`-517`); `vdda`/`vddpe-3v3` fall back to dummy regulators.
- `arm-scmi`: channel setup fails for protocol `0x10`.
- `reserved-memory`: `ta@d8600000` fails to reserve; depthcharge's `ramoops` and several firmware-added `region@…`
  nodes overlap the DT's own reservations (warnings only).
- Firmware log: depthcharge disables the NVMe controller and all USB controllers before the jump
  ("Exiting depthcharge with code 4").
