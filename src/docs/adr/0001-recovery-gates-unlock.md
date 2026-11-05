# 1. No bootloader unlock until a way back to stock is proven

## Status

Accepted (from the project log, 2026-10-17; recorded as an ADR 2026-10-21)

## Context

Unlocking the bootloader wipes all data and disables device security
([Google Help](https://support.google.com/googlebook/answer/17389679)). The device is new and the only one the
owner has. Dell's Service Manual (Rev. A00, pages 65-66) documents USB recovery media from Google's Device
Recovery Utility, but nobody has shown that it restores a device that was unlocked, that has a blank or foreign
SSD, or that it lets the bootloader be relocked. Google may serve only the latest image, so anti-rollback could
block an older build.

## Decision

Phase 2 (unlock) starts only after Gate 1 passes:

- recovery media made and tested to reach the recovery screen,
- the working recovery key combo recorded,
- the recovery image and its build number saved,
- build fingerprint and bootloader version recorded,
- device-specific data that Phase 2 needs is backed up or dumped.

Agents never unlock, flash or enter recovery or fastboot; the owner does those steps by hand.

## Consequences

Phase 1 stays on the stock OS, read-only over adb, which slows the start but keeps the device returnable.
The spare-SSD approach ([ADR 0002](0002-experiment-on-spare-ssd.md)) reduces risk further but does not replace
this gate, because the bootloader state lives in firmware, not on the SSD.

## Update 2026-10-21

- Google's recovery image for mica is public: `mica-user/16471258/recovery.zip` (downloaded to `dumps/`,
  sha256 in [stock-dtb.md](../research/stock-dtb.md)). Its build `CL3B.260622.273.R1/16471258` (AVB rollback
  index 1339) is **older** than the installed `CL3B.260622.276.R2/16560795`. Whether anti-rollback accepts it is
  unknown, so it does not pass Gate 1 by itself.
- Unlocking is ChromeOS developer mode ([ADR 0003](0003-first-boot-chromeos-kernel-partition.md)). "Lock
  bootloader" on the developer screen returns to normal mode. Whether that restores verified boot without a
  reinstall is still untested.
- Still required for Gate 1: Device Recovery Utility media made and booted to the recovery screen, and the build
  it serves compared with the installed one.

## Update 2026-10-21 (recovery steps)

Google's [Recover your Googlebook](https://support.google.com/googlebook/answer/17452429) (read 2026-10-21) documents:
- **Media:** recovery media from the Device Recovery Utility in Chrome on a Chromebook, Windows or Mac. Linux is not
  listed. The drive is 32 GB or more and gets erased.
- **Recovery mode:** Esc + F2, then Power. Esc + Refresh in Dell's Service Manual is the Chromebook combo.
- **Recovery erases:** recovering "permanently erases everything".

For Gate 1, the owner stops at the recovery screen and does not select **Use USB drive**. The checklist lives in
Pass Gate 1.

## Update 2026-11-02 (Gate 1 passed)

Device Recovery Utility media reaches the recovery screen with Esc + F2, and serves
`CL3B.260622.276.R2/16560795`, the installed build (rollback index 1339). A full copy of the stick is in `dumps/gate1/`.
Details: Pass Gate 1. The relock test runs on unlock day,
before any Linux boot (unlock-day ticket).
