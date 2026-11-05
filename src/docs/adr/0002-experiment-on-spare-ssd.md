# 2. Experiment on a spare M.2 2230 SSD; keep the stock drive intact

## Status

Accepted (from the project log, 2026-10-17; recorded as an ADR 2026-10-21)

## Context

Dell's Setup and Specifications guide (Rev. A00) lists one M.2 2230 PCIe Gen4 x4 NVMe slot, and the Service
Manual reaches the SSD right after the base cover (4 Torx T5 screws). The SSD is a field-replaceable part. Dell
names "Google Qualified" drives, so an unlisted drive may or may not be accepted.

## Decision

All Linux experiments run on a second 2230 SSD. The stock drive comes out and stays in a drawer. Before any
internal work: disconnect the battery-cable bracket and hold power for 20 s (Service Manual).

## Consequences

- Returning to stock is a drive swap, as long as the bootloader and firmware state allow it (see ADR 0001).
- Open, testable questions: does the firmware accept an unlisted drive; does a cloned stock drive boot (tells
  whether the drive is bound to the device); do recovery and fastboot live in the 32 MB firmware flash (a blank
  drive answers that, since fastbootd lives on the SSD).
- Opening the case may matter for warranty; the owner decides when.

## Update 2026-10-21

The stock internal disk (from the recovery image's GPT, [stock-dtb.md](../research/stock-dtb.md)) mixes ChromeOS
`KERN-A/B` and `ROOT-B` with Android A/B partitions (`boot_*` use the ChromeOS-kernel type GUID). The first Linux
boot goes on external or spare storage ([ADR 0003](0003-first-boot-chromeos-kernel-partition.md)). Nothing in
that plan needs the stock drive.

## Update 2026-10-21 (first boot)

Owner decision (boot media and port hookup):
- **First boot:** Phase 2 runs from a dedicated USB stick in the right USB-C port, on battery.
- **Spare SSD:** deferred to Phase 3, when Linux needs persistent storage.
- **Stock SSD:** for Phase 2 it **stays installed** rather than in a drawer, and it is never written
  ([ADR 0003](0003-first-boot-chromeos-kernel-partition.md)). It is the fallback boot, and the stock OS on it reads
  back a failed boot's ramoops through dropbox.

The rest of this decision applies once Phase 3 starts.

