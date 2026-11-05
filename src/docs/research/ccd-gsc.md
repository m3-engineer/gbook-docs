# Closed Case Debugging on mica with the SuzyQ

Tested 2026-10-21 on the build host with a Fyra Labs SuzyQ Board. CCD stayed **Locked**, nothing was opened or flashed,
and the only commands sent to the GSC were `version` and `ccdstate`. Per-unit identifiers (the Ti50 USB serial
number, chip ID and pcr0) are left out.

## Hookup that works

- The SuzyQ's USB-C plug goes into the Googlebook's **left** USB-C port. The board's own USB-C socket goes to
  the build host with a data cable. The board is only a pass-through; it needs both connections at once
  ([Fyra docs](https://developer.fyralabs.com/suzyqboard): "The SuzyQ USB-C connector goes into the CCD port …
  You must provide a USB cable that can carry data").
- It enumerated in the first orientation tried. The other orientation and the right port were not tested.
- the build host sees `18d1:5066 Google Inc. Ti50`. Linux's `usb_serial_simple` ("google converter") creates the ttys.
  Note the ID: the GSC doc names `18d1:504a`, but this Ti50 reports `5066`.

| tty | USB interface | Console | Seen 2026-10-21 |
|---|---|---|---|
| `ttyUSB0` | 0 `Shell` | GSC (Ti50) shell | answers commands |
| `ttyUSB1` | 1 `AP` | AP UART | silent: the stock kernel has `console=null console=ttynull` |
| `ttyUSB2` | 2 `EC` | EC console | logs events |
| `ttyUSB3` | 6 `FPMCU` | fingerprint MCU | silent |
| (none) | 3 `Ti50 Update`, 4 `SPI`, 5 `I2C` | firmware update, flash and I2C bridges | not used |

Use `/dev/serial/by-id/usb-Google_Inc._Ti50_*-if0N-port0` instead of the `ttyUSBN` numbers, which can change.

## the build host access

The ttys are `root:uucp 0660` by default. Since 2026-10-21, `/etc/udev/rules.d/70-ti50-ccd.rules` tags
`SUBSYSTEM=="tty"` with `ATTRS{idVendor}=="18d1"` and `ATTRS{idProduct}=="5066"` as `uaccess`, so the active
desktop session gets an ACL. It sorts before systemd's `73-seat-late.rules`, which applies the tag. Check with
`getfacl /dev/ttyUSB0`. To undo, delete the file.

## Reading safely

Turn off local echo first, or the tty line discipline echoes received bytes back into the console:

```bash
stty -F /dev/ttyUSB2 raw -echo -echoe -echok -echoctl -echoke
timeout 60 cat /dev/ttyUSB2          # EC: passive
printf 'ccdstate\r' > /dev/ttyUSB0   # GSC: one command, read the reply from a cat already running on ttyUSB0
```

## What it showed

**GSC `version`:**
- RO: A `0.0.113`, B `2.0.119` (active).
- RW: A `0.33.270`, B `0.33.291` (active), `ti50a_common_mp-16604.B:v0.0.151-54d5cc09`, built 2026-06-11.
- This matches `gsctool -a -f` from adb (RO 2.0.119 / RW 0.33.291).

**GSC `ccdstate`:**

| Field | Value | Meaning |
|---|---|---|
| `AP` | on | |
| `Servo` | disconnected | |
| `Rdd` | connected | the GSC sees the debug accessory on the left port |
| `CCD_MODE` | asserted | |
| State flags | `UARTAP+TX UARTEC UARTFPMCU` | the AP UART is bridged **both ways**; EC and FPMCU are read-only |
| CCD ports blocked | none | |

`gsctool -a -I` from adb shows CCD `Locked` with `UartGscRxAPTx`, `UartGscRxECTx` and `UartGscRxFpmcuTx`
allowed `Always`. `UartGscTxAPRx` shows `Y Always` too, which explains `UARTAP+TX`.

**EC console (Zephyr logging), charger test:**

```
I: ADSP: Charging from USB0
I: ADSP: Charging from USB1
```

The EC reports charge-port changes coming from the SoC's ADSP. That fits the stock DT's `pmic-glink` and UCSI
connectors: on Linux, battery and USB-C state go through the ADSP, as on other X1 laptops, and the EC is told.

## What it means for bring-up

- **A console for the first boot exists.** The AP UART is bridged both ways while CCD is locked. A mainline kernel
  booted with `console=ttyMSM0,115200` (or the right GENI UART) should print to `ttyUSB1`. Which GENI serial
  engine is wired to the GSC is still to be found in the stock DT (*inference to test*).
- The EC console shows charge and power events during experiments, with no unlock needed.
- Still locked: `FlashAP`, `FlashEC`, `OverrideWP` and `GscFullConsole` need CCD opened. Opening needs developer
  mode, `gsctool -a -o` and power-button presses ([boot path, section 5](chromeos-boot-path.md#5-closed-case-debugging)).

## Open

- The right port and the other plug orientation (does CCD work only on the left port, which matches coreboot's
  single `DAP_USE_SMB1`?).
- Whether depthcharge prints to the AP UART during boot. A reboot while `ttyUSB1` is being read would show it.
  That is a harmless test, but it reboots the owner's device, so it needs the owner's OK.
