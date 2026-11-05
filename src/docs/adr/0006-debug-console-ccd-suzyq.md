# 6. Debug console through GSC CCD and a SuzyQ, read-only while CCD is locked

## Status

Accepted 2026-10-21.

## Context

First boot needs a console that works before display or USB drivers do. Tested 2026-10-21
([ccd-gsc.md](../research/ccd-gsc.md)):
- A Fyra Labs SuzyQ in the Googlebook's **left** USB-C port exposes the Ti50 as `18d1:5066`, with Shell, AP,
  EC and FPMCU consoles.
- `ccdstate` shows `UARTAP+TX`: the AP UART is bridged both ways while CCD is **Locked**.
- The stock and mainline DTs both name `uart21` (`0x894000`) as `serial0`.
- Opening CCD (`gsctool -a -o` plus power-button presses) needs developer mode, and it changes GSC state.

## Decision

- **Kernel console:** `uart21` is the first-boot console: `stdout-path = "serial0:115200n8"`,
  `console=ttyMSM0,115200`. the build host reads it through the SuzyQ's AP console.
- **Read only:** agents run the SuzyQ consoles read-only. Before reading, run `stty raw -echo` on the tty so
  nothing echoes back. On the GSC shell, agents send only read-only commands (`version`, `ccdstate`, `help`).
  Never `ccd open`/`unlock`/`reset`, `wp`, `reboot` or any flash command.
- **Opening CCD** (for a full AP flash backup over `raiden_debug_spi`) is an owner decision. It happens after
  unlocking and gets its own ADR.
- **the build host access:** the `uaccess` udev rule `/etc/udev/rules.d/70-ti50-ccd.rules` (owner choice over joining
  `uucp`).

## Consequences

- The left USB-C port is taken by the SuzyQ during bring-up. Boot media and power go through the right port (a
  hub with PD pass-through) or the spare SSD.
- If the AP console stays silent under Linux, the fallbacks are ramoops (depthcharge always reserves it) and the
  panel.

## Update 2026-10-21

- **The DTS has the console now:** it sets `stdout-path = "serial0:115200n8"` (commit `709212e`).
- **Read-only still applies with our own kernel:** the first-boot initramfs prints its captures, then reboots, and
  has no shell (Initramfs contents and pass criteria).
- **Logs:** raw AP-console logs go to `dumps/firstboot/`.
- **Second channel:** when the console is silent, the stock OS's dropbox `SYSTEM_LAST_KMSG` holds the failed boot's
  last 64 KiB (stock pstore).
