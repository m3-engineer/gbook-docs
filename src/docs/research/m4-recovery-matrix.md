# M4 recovery matrix: Valve's five rows mapped onto mica's ChromeOS mechanisms

Written 2026-11-05, 10:58 AM EST [15:58 UTC], task #32 (owner decision 2026-11-05 on
[steamos-arm.md](steamos-arm.md), "Decisions", 1). Planning material for M4 (daily-drivable, Gate 3:
[ADR 0010](../adr/0010-milestones-status-upstream-hold.md): "installed on the spare SSD, with dual-boot or a documented
return to stock"). Nothing here was run on the device; no ADR is written yet (the slot policy is an open owner
decision below). Every row carries one of three labels: **proven on mica** (an attempt id or log row), **proven in
source** (a research note's `file:line` at its pin), or **inference / untested**. The vboot and depthcharge citations
come from [fit-packaging.md](fit-packaging.md) and [chromeos-boot-path.md](chromeos-boot-path.md), both pinned at
`firmware-bluey-16702.B`; this note does not reopen the source.

## Answer in short

M4's "documented return to stock" is already proven except for the physical swap. [ADR 0002](../adr/0002-experiment-on-spare-ssd.md)
puts M4 on a spare M.2 2230 SSD with the stock drive in a drawer, and [ADR 0003](../adr/0003-first-boot-chromeos-kernel-partition.md)
forbids writing the stock drive, so dual-boot on the stock SSD is excluded; "dual-boot" today is stick in, stick out
([status](../status.md) row "Reboot back to stock": stock boots once the stick is out, proven 2026-11-02-2 and
2026-11-03-5). Return at M4 is therefore: power off, put the stock SSD back, power on, Boot from internal disk, and
Lock bootloader if a locked device is wanted. Lock bootloader wiping the data and relocking **without** the recovery
stick is proven (project log 2026-11-02, "Unlock day, relock test passed"; `recon.sh` read `green`, `flash.locked=1`,
`locked`). What is untested is what ADR 0002 already lists: does the firmware accept an unlisted drive, does a blank
drive still reach recovery and fastboot, and is the drive bound to the device. That turns M4's gate from "design a
recovery system" into three owner-run probes (section "Test plan before M4").

The Frame's five rows and mica's answers:

| Need | Steam Frame (first-party recipe) | mica today (M3, stick) | mica at M4 (spare SSD) | Label |
|---|---|---|---|---|
| Boot the previous OS, keep data | AUX + power, "Previous B" in the U-Boot menu; `splctl set-state <slot> good` after a verified boot | no slot picker in the dev-mode menu (Lock bootloader, Boot from internal disk, Boot from external drive); vboot picks the highest-priority kernel entry with tries or successful, deducts a try from a `successful=0` entry, marks a failing entry 0/0 | the same vboot rules on the SSD: two kernel partitions, "previous" is either the automatic fallback when the new one's tries run out, or a `cgpt` write from the running OS before reboot | proven in source (vboot selection, [fit-packaging.md](fit-packaging.md) section 5); the count-down proven on mica (retro-7/08: 3 tries ran out after 3 boots, so packaging sets 15); the two-slot layout untested |
| Reset the OS, keep user data | "Repair Steam Installation" menu entry; `steamos-reset-tool` from Settings | none: the stick's ROOT is rewritten whole with `attempt.sh root-cmd` | rewrite the inactive root partition from the build host or from the running OS, user data on its own partition | inference (nothing exists) |
| Wipe user data without booting the OS | "Erase User Data" menu entry (`/efi/steamos/factory-reset`) | none | a `mke2fs` of the data partition from `/init` behind a command-line flag (proposal; the M4 shape of #36) | inference (nothing exists) |
| Reinstall from USB | boot menu, USB repair stick, "Wipe Device & Install SteamOS" | the Gate 1 recovery stick: Esc + F2, then Use USB drive; erases the disk, installs `16560795` (the installed build) | the same stick; with the spare SSD installed it would install stock onto the spare drive, untested | proven on mica to the recovery screen (Gate 1, 2026-11-02, ADR 0001 update); the install itself never run; the firmware rewrite it may do is inference (runbook section 9) |
| Unbrick the boot firmware | a QDL (EDL) package, 4.1 GB | no EDL path documented; ChromeOS recovery mode is the only path, CCD stays locked, no agent writes firmware (ADR 0001, [ADR 0006](../adr/0006-debug-console-ccd-suzyq.md)) | the same | proven in source that depthcharge's fastboot has no `boot` and no unlock command (chromeos-boot-path.md section 4); "no EDL path" is the absence of evidence, stated as such |
| Know the state | "Purple, solid: in bootloader" (LED) | the AP console and the EC's power lines over SuzyQ (`attempt.sh watch` classifies them); LED codes 3,5 and 4,3 (runbook section 8); Advanced options > Firmware log; the dev-mode warning screen | the same | proven on mica (every boot since 2026-11-02; the three release boots of 2026-11-05 had no AP console because the SuzyQ was unplugged on the build host's side, and the netlog covered only the post-Wi-Fi window) |

## 1. Previous slot: what vboot does, and what the owner can do

- **Selection** ([fit-packaging.md](fit-packaging.md) section 5, vboot at `firmware-bluey-16702.B`): `GptNextKernelEntry`
  skips entries with neither `successful` nor `tries` and picks the highest priority (`cgptlib.c:44-120`); a booted entry
  with `successful=0` loses a try (`2load_kernel.c:768-779`); with `successful=1` tries are ignored (`cgptlib.c:135-144`);
  a failing entry is marked bad, 0/0, and the next one is tried (`2load_kernel.c:742-743`).
- **On mica today**: the stick's KERN-A is written `-S 0 -T 15 -P 15` (`scripts/package-in-container.sh`, retro-7/08):
  depthcharge takes one try per boot, nothing marks the kernel successful, and `successful=0` keeps the 0/0 mark a
  rejected kernel gets ("No valid image detected", runbook section 8). `attempt.sh stick` prints the tries left and
  `new` warns at 0. Proven on mica: 3 tries ran out after 3 boots on 2026-11-04.
- **The Frame's `set-state good`** maps to `cgpt add -i <N> -S 1` on the boot disk from the running OS after a verified
  boot (`cgpt add -S/-T/-P`, `cmd_add.c:16-33`). Two consequences:
  - The rootfs has no `cgpt` today (`rootfs/packages.txt`, read 2026-11-05); Debian ships it in `cgpt` (source
    `vboot-utils`): a package to add for M4, to be checked with `scripts/size-rootfs.sh` first.
  - It is a GPT write to the boot disk: M4 work under the owner's OK, never in the stick era, where the stick is the
    only disk gbook writes and the build host writes it.
- **"Previous" without a menu**: with two kernel partitions on the SSD (`KERN-A`, `KERN-B`), "boot the previous OS"
  is either the automatic fallback (the new slot's tries run out, or it is rejected and marked 0/0, and vboot takes the
  other) or an explicit `cgpt add -i <old> -P <higher>` before reboot. Neither is a key press at power-on. The
  firmware-fastboot `oem set-priority` and `oem set-successful` exist (chromeos-boot-path.md section 4) but need an
  ALink or PL27A1 bridge or a USB-Ethernet adapter over DHCP: **not available with the current hardware**.
- **The policy decision** (open, grilling question 1): keep the stick's count-down (`-S 0 -T n`, a bad kernel marks
  itself 0/0, a good one still runs out of tries unless something writes `successful`), pmbootstrap's installed-system
  values (`-S 1 -T 5 -P 10`, unlimited boots, no 0/0 signal), or two slots with the OS flipping `successful` after a
  verified boot (Valve's shape; the "verified" test is gbook's: `m3-end` reached, the names heard, the audio state read).

## 2. Reset the OS, keep user data

Nothing exists. Today the whole ROOT partition is rewritten from the build host (`attempt.sh root-cmd`, `root-verify`), which is
the stick's "reinstall". At M4 the analogue is a root partition per slot (`ROOT-A`, `ROOT-B`) and a separate data
partition (`home`, or Valve's `var` + `home` split), so that a root rewrite leaves the data. Valve's update discipline
(write the inactive slot, read back, compare, only then switch) is the one `attempt.sh verify` already follows for the
stick; keep the ordering when KERN-B comes (steamos-arm.md, section 5, second proposal). *Inference throughout; no
partition layout is decided.*

## 3. Wipe user data without booting the OS

Nothing exists. Proposal: `/init` takes a command-line flag (`gbook.wipe=data`, name open) and runs `mke2fs` on the
data partition, after printing what it is about to erase on the AP console and the panel, with a countdown. It needs
`mke2fs` in the initramfs (busybox has `mkfs.ext2` only; check before relying on it) and a way to set the flag without
a rootfs: on the stick era that is a repackage; at M4, `cgpt` can only set attributes, not the command line, so the
flag would live in the FIT's command line of a dedicated "wipe" kernel entry (*inference*), or the wipe stays a the build host-side
operation on the swapped-out drive. Task #36 covers the read-only lock in `/init`; this flag is its M4 sibling.

## 4. Reinstall from USB: the recovery stick

- **Proven**: Device Recovery Utility media reaches the recovery screen with Esc + F2 and serves `16560795`, the
  installed build (Gate 1, 2026-11-02; ADR 0001 update). A full copy is in `dumps/gate1/`.
- **Never run**: Use USB drive. Runbook section 9: it erases the disk and installs `16560795`; the stick's ROOT-B
  carries `chromeos-firmwareupdate`, so a recovery **may rewrite AP and EC firmware** (*inference*).
- **Two hazards Valve's recipe has no analogue for**:
  - the recovery keys with the image stick inserted mark KERN-A bad (runbook section 8; proven on mica,
    [wifi-2026-11-03.md](../recon/wifi-2026-11-03.md): the owner powered on with the recovery keys and the stick was
    rejected), so the image stick and the recovery stick are different Lexar drives and the recovery one stays out
    unless a recovery is intended;
  - with the spare SSD installed, Use USB drive would install stock onto the spare drive (*inference*), which is the
    "unlisted drive" probe's second half: does it install, and does the result boot.

## 5. Unbrick the boot firmware

No EDL path is documented for mica. The boot firmware is depthcharge (`Google_Mica.16702.*`); CCD stays Locked and
the agent rules forbid every firmware write (ADR 0001, ADR 0006, CLAUDE.md). ChromeOS recovery mode plus the recovery
stick's firmware updater (inference, section 4) is the only path on record. Valve's QDL package is an answer for a
Qualcomm device whose PBL exposes EDL; whether mica's does is unknown and stays untested: an EDL probe would need a
cable in the data lines at power-on and is outside every gate.

## 6. Know the state

| Signal | What it shows | Where |
|---|---|---|
| AP console over SuzyQ (`-if01`) | depthcharge's screens as text, the kernel's early log, every `GBOOK:` capture | `attempt.sh watch`, `attempt.sh follow` |
| EC console (`-if02`) | the power sequence: `EC: POWER ON (S5->S3)`, `powered off (S5->G3)`, `soft-off` | `attempt.sh watch` (`scripts/ec_power.awk`) |
| LED codes | 3,5 = EC power-on timeout; 4,3 = LCD fail at the firmware stage | runbook section 8 |
| The dev-mode warning screen | the device is unlocked; its menu has the three entries | depthcharge `screens.c:1801` (unlock-day ticket) |
| Advanced options > Firmware log | why depthcharge refused an image | runbook section 8 |
| `scripts/recon.sh` on stock | `verifiedbootstate`, `flash.locked`, `vbmeta.device_state` | the relock test |
| The netlog | the kernel log after Wi-Fi joins, the rootfs journal | `attempt.sh netlog` |

The netlog is the fallback when the SuzyQ is out, not a replacement: it starts after Wi-Fi joins (about 35 s) and shows
nothing of depthcharge. The three release boots of 2026-11-05 ran that way (log row "Release bar met for
`v2026.11.05`").

## Test plan before M4 (owner only, no agent writes)

Each step opens the case: ADR 0002's prerequisite (disconnect the battery-cable bracket, hold power 20 s, Service Manual)
and the warranty note apply. In order, each one a dated recon note:

1. **Blank-SSD probe** (project log Phase 3 list): the spare SSD, empty, installed; power on with no keys. Learns whether
   recovery and fastboot live in the 32 MB firmware flash (fastbootd lives on the SSD), and what the firmware shows with
   no bootable disk (the dev-mode menu, or recovery). The SuzyQ records it.
2. **Unlisted-drive probe** (ADR 0002): the spare SSD with a gbook install written on the build host (the stick's layout: KERN-A
   plus ROOT, `cgpt` attributes as decided in grilling question 1). Boot from internal disk. Pass = `m3-end` on the
   netlog and the names heard. Dell lists "Google Qualified" drives; this is the test of whether an unlisted one is
   accepted at all.
3. **Swap-back probe**: the stock SSD returns; power on; Boot from internal disk; stock boots (`recon.sh` reads
   `orange`, unlocked, the installed build). Then, if the owner wants the locked state: Lock bootloader (wipes;
   proven to relock without the recovery stick on 2026-11-02), stock boots, `recon.sh` reads `green`, `flash.locked=1`,
   `locked`. **This probe is the one that closes M4's "documented return to stock".**

Optional, after 2: the recovery stick with the spare SSD installed (section 4's second hazard), only if the owner wants
stock on the spare drive too.

## Commands (named, not run)

| Purpose | Command | When |
|---|---|---|
| Read a disk's kernel entries | `cgpt show -i <N> -P` / `-T` / `-S` (or `-A`) `<disk>` | any time on the build host against the stick (`attempt.sh gpt` wraps it) |
| Mark the booted kernel good (Valve's `set-state good`) | `cgpt add -i <N> -S 1 <disk>` | M4, from the running OS, owner's OK, after the verified-boot test |
| Prefer the other slot before a reboot (Valve's "Previous") | `cgpt add -i <other> -P 15 <disk>` (and `-T 1 -S 0` to try it once) | M4, owner's OK |
| Re-arm a rejected entry | rewrite the image (`attempt.sh dd-cmd`); `cgpt add -i 1 -T 15 -P 15` alone would re-arm a kernel the firmware already refused | after "No valid image detected" |
| Return to stock, stick era | pull the stick, power on | proven |
| Return to stock, M4 | swap the stock SSD back, Boot from internal disk, Lock bootloader if wanted | the swap-back probe |

## Decisions (owner, 2026-11-05, 11:02 AM EST)

Grilling round; the owner took every recommendation:

1. **Slot policy**: two kernel partitions on the SSD; the OS marks the booted one `successful` after the verified-boot test
   (`m3-end` reached, the names heard), so a bad update falls back by itself. `cgpt` joins the rootfs for M4.
2. **The stick stays** as a second recovery path at M4.
3. **The data-wipe flag** in `/init` comes at M4, when a data partition exists (not with task #36).
4. **The M4 ADR** is written after the three probes, with their results.

## Open questions (grilling round, as asked)

1. Slot policy for the SSD install (section 1): count-down as the stick, installed-system values, or two slots with the
   OS flipping `successful` after a verified boot.
2. Whether M4 keeps the stick as a second recovery path (the proven one; it costs nothing).
3. The data-wipe flag in `/init` (section 3): with #36 now, or at M4.
4. The ADR: now, or after the three probes.

## Sources

| Source | What | Read |
|---|---|---|
| [steamos-arm.md](steamos-arm.md) section 5 | the Frame's boot menu, `splctl`, the first-party recovery matrix (Steam Support pages 1B71-EDF2-EB6D-2BB3 and 65B4-2AA3-5F37-4227), the update discipline | 2026-11-05 |
| [fit-packaging.md](fit-packaging.md) section 5 | vboot selection and attribute bits at `firmware-bluey-16702.B` (`cgptlib.c`, `2load_kernel.c`, `cmd_add.c`, `cmd_show.c`); pmbootstrap's values; the stock `boot_a` with priority 0 | 2026-10-21 note, re-read 2026-11-05 |
| [chromeos-boot-path.md](chromeos-boot-path.md) sections 2, 3, 4, 6 | developer mode, Route A, firmware fastboot's commands and transports, the recovery image | 2026-10-21 note, re-read 2026-11-05 |
| [ADR 0001](../adr/0001-recovery-gates-unlock.md), updates 2026-10-21 and 2026-11-02 | Gate 1 passed; the recovery combo; the relock test's place | 2026-11-05 |
| [ADR 0002](../adr/0002-experiment-on-spare-ssd.md) | the spare SSD, the three open probes, the case-opening prerequisite | 2026-11-05 |
| [ADR 0003](../adr/0003-first-boot-chromeos-kernel-partition.md) | the stock drive is never written; the ChromeOS kernel partition route | 2026-11-05 |
| [ADR 0010](../adr/0010-milestones-status-upstream-hold.md) | M4's "done when" | 2026-11-05 |
| runbook, first boot sections 5, 8, 9 | unlock day and the relock test; the failure playbook (0/0 mark, Firmware log, LED codes); back to stock | 2026-11-05 |
| unlock-day ticket | the dev-mode menu's three entries (depthcharge `screens.c:1801`); the relock pass criteria | 2026-11-05 |
| project log, 2026-11-02 "Unlock day, relock test passed"; 2026-11-04 "Retro-7/08: stick boot tries" | the relock proven without the recovery stick; the count-down proven, 15 tries | 2026-11-05 |
| [status.md](../status.md) rows "Boot from USB" and "Reboot back to stock" | stock boots once the stick is out | 2026-11-05 |
| `rootfs/packages.txt` | no `cgpt` in the rootfs | 2026-11-05 |
| `scripts/package-in-container.sh` (the GPT comment), `scripts/attempt.sh` (`stick_tries`) | the stick's `-S 0 -T 15 -P 15` and the tries bookkeeping | 2026-11-05 |
