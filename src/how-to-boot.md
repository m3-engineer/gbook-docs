# Boot a gbook image on mica

A how-to for one boot attempt of a gbook kernel image from a USB stick, written from the project's own runbook with
the host-specific tooling left out. It assumes you have an image: the build recipe is documented
([How mica boots Linux](how-mica-boots.md), the [kernel configuration](kernel/README.md) and [patch](kernel/patches/README.md)
pages) and the build scripts are published with a later release. No image download exists yet.

Roles in the project: a person does every key press, every unlock and every write to a stick; an agent builds, checks
and reads consoles ([ADR 0001](docs/adr/0001-recovery-gates-unlock.md)). If you are alone, you are both.

## Before the first attempt (once)

1. **Prove the way back first.** Make a Google recovery stick for this model with the ChromeOS recovery tool, boot it
   once with the recovery keys (Esc + Refresh (F2) + Power) and confirm you reach its screen, then label it and never
   rewrite it. The project calls this Gate 1; nothing else happens before it passes (ADR 0001).
2. **Back up what you care about** on the machine. Developer mode wipes user data.
3. **Unlock the bootloader** on your own responsibility. On this model the steps are Google's: turn on OEM unlocking
   in the system's Developer options, hold Esc + Refresh (F2) + Power to reach the recovery screen, then Advanced
   options, Unlock bootloader. The firmware screen reads "Bootloader is unlocked" from then on, and self-signed kernels
   boot from an external drive without further settings (the boot-path note,
   [chromeos-boot-path.md](docs/research/chromeos-boot-path.md), "Unlock = developer mode").
4. **A second stick** for images: USB 3, 4 GB or more, used for nothing else. Keep it visibly different from the
   recovery stick; the project once put the recovery stick in by mistake and Google recovery ran.
5. Optional but useful: a SuzyQ debug cable in the **left** port gives the AP console
   ([ADR 0006](docs/adr/0006-debug-console-ccd-suzyq.md)). Without it the panel and, once Wi-Fi is up, the network log are
   the only channels.

## Write the stick

1. Write the whole image to the stick's block device with `dd`, addressing the stick by its stable device path (for
   example under `/dev/disk/by-id/`), never by a letter that can change. The image is a complete disk of 256 MiB: a GPT
   with a 128 MiB ChromeOS kernel partition holding the signed FIT, and, on the same stick from 256 MiB on, a second
   partition for a rootfs when one is used
   ([ADR 0003](docs/adr/0003-first-boot-chromeos-kernel-partition.md)).
2. Read the stick back and compare it with the image before you unplug it. Every rewrite also resets the kernel
   partition's tries counter: depthcharge spends one try per boot, and the image sets 15.
3. Power the stick off or eject it cleanly, then carry it straight to the laptop.

## Boot

1. Power the laptop off. Check: image stick in the **right** port, no charger, no hub, lid open. Battery at half or more.
2. Power on with **no keys held**. On the "bootloader is unlocked" screen choose **Boot from external drive**.
3. **Never press the recovery keys with the image stick in.** Recovery mode scans the stick for a Google-signed kernel,
   rejects the developer-signed one and marks the kernel partition bad; the stick then needs a rewrite (the project
   lost two boots to this on 2026-11-03).
4. If you see "Recovering your device", the recovery stick is in. **Interrupt nothing.** It reinstalls the same build
   and leaves developer mode on; a cut firmware update can brick the device.
5. The first lines appear on the AP console at about 0.6 s and on the panel once the display driver is up. The
   initramfs prints `GBOOK:` status lines; with a rootfs on the stick it hands over to it, otherwise it reboots after its
   sweep. Pull the stick as soon as it reboots so the next boot is stock; with the stick still in, the firmware waits on
   its boot screen.
6. SCMI needs a cold boot. After a warm reset from stock the CPUCP answers late or not at all and cpufreq fails, so
   power the machine off before each attempt ([SCMI over the CPUCP mailbox](scmi-cpucp.md)).

## If nothing appears

| What you see | What to do |
|---|---|
| Looks hung | Wait two minutes for the kernel's own panic reboot before holding Power (8 s); a forced reset usually loses the ramoops log |
| Firmware says "No valid image detected" | The first refusal marks the kernel partition bad on the stick; re-inserting cannot work. Rewrite the stick |
| Prints, then hangs at a driver | Disable that device-tree node for the next attempt, one change per attempt |
| LED code 3,5 | EC power-on timeout: charge, end the session, retry the same image later |
| Nothing new after five attempts | Stop and ask; the project's failure signatures are in the boot-path and first-boot notes |

## Back to stock

Esc + Refresh + Power with the **recovery** stick in the right port, then "Use USB drive or SD card". It erases the
disk and installs the build the stick carries. The project's own return-to-stock plan, including the untested probes with
a spare SSD, is in [the M4 recovery matrix](docs/research/m4-recovery-matrix.md).
