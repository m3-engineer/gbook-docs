# Feature status

As of 2026-11-05, 1:57 PM EST. Kernel: torvalds `a804c57` plus `kernel/patches/0001`-`0011`. Board DTS:
[`dts/x1e80100-google-mica.dts`](../dts/x1e80100-google-mica.dts). The default state is "untested". Every row cites
the recon note it rests on, or "none" when no note covers it.

This is the feature matrix of [ADR 0010](adr/0010-milestones-status-upstream-hold.md): the
[milestones note](research/milestones-versioning.md), recommendation 2, which the owner adopted on 2026-11-04 ("all a"
to its section 5). Asahi and Nura publish their feature tables the same way.

Patch numbers: 0008 and 0009 here are the PCIe GDSC and PCIe PHY GDSC retention patches. Both numbers named other
patches before the rule against reusing numbers. 0008 was a GENI I2C timing test (commit `16a2828`, attempt
2026-11-04-2), and 0009 was the IRQ-to-CPU-1 diagnostic (commit `cee735d`, attempt 2026-11-04-3, deleted by
[ADR 0009](adr/0009-no-psci-cpuidle.md)). Recon notes about those two attempts mean the old patches.

## Legend

- **State:** `works`, `partial`, `broken` or `untested`. A parked row keeps its state, and its note says "parked
  until <milestone or condition>" ([ADR 0010](adr/0010-milestones-status-upstream-hold.md), update 2026-11-04).
- **Where it works:**
  - `mainline at a804c57`: the driver is unchanged;
  - `+ patch NNNN`: a local patch in `kernel/patches/`;
  - `board DTS`: needs the mica device tree;
  - `config fragment (name)`: `kernel/<name>.config` builds the driver in, because the initramfs loads no modules.
  - These combine as needed; `—` means it works nowhere yet. In the Upstream column, `—` means there is nothing to
    report.
- **Upstream:** what mainline or linux-firmware already has, and what gbook would have to send.
  - "mica DTS not sent" covers both the board DTS and the `google,mica` binding ([dts/README.md](../dts/README.md),
    "Before sending upstream").
  - The patch words follow ChromiumOS, with `LOCAL` in place of its `CHROMIUM`: `FROMLIST` means posted to a list
    but not merged, and `LOCAL` means carried here and not sent.
  - Nothing is sent before M5.
- **Evidence:** the dated recon note, plus the attempt id where the note gives one. "none" means no note covers the
  feature.
- **Note:** kept short. *inference* marks a judgement call, such as the choice of state.

## Boot and consoles

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| Boot from USB (dev-signed FIT, KERN-A) | works | mainline at a804c57 + board DTS | mica DTS not sent | [firstboot](recon/firstboot-2026-11-02.md), 2026-11-02-2 | right port; power on with no keys held, because the recovery keys mark the stick bad ([wifi](recon/wifi-2026-11-03.md), update) |
| Kernel at EL2 | works | mainline at a804c57 + board DTS (with `x1-el2.dtso`) | overlay in mainline; mica DTS not sent | [firstboot](recon/firstboot-2026-11-02.md), 2026-11-02-2 | `All CPU(s) started at EL2`; KVM not tried |
| AP console (`uart21`, `ttyMSM0`) | partial | mainline at a804c57 + board DTS | mica DTS not sent | [firstboot](recon/firstboot-2026-11-02.md), 2026-11-02-2 | output from about 0.6 s; earlycon prints nothing before `ttyMSM0` probes (*inference*: partial) |
| Panel console (simpledrm, then msm fbcon) | works | mainline at a804c57 + config fragment (mica-firstboot, mica-display, mica-console) | drivers in mainline | [firstboot](recon/firstboot-2026-11-02.md), 2026-11-02-2; [display](recon/display-2026-11-03.md), 2026-11-03-4 | coreboot framebuffer first; msm takes over at 1.6 s; banner on `tty1` |
| ramoops, read back through dropbox | works | mainline at a804c57 + config fragment (mica-firstboot) | drivers in mainline | [firstboot](recon/firstboot-2026-11-02.md), 2026-11-02-2; [wifi](recon/wifi-2026-11-03.md), 2026-11-03-3 | read on the next stock boot; later boots start mid-log, with no banner |
| Netlog over Wi-Fi | works | n/a (gbook `/init`, `attempt.sh netlog`) | n/a | [wifi](recon/wifi-2026-11-03.md), 2026-11-03-3 | whole boot from 0.0 s, sent after `GBOOK: end` |
| Reboot back to stock | works | mainline at a804c57 | n/a | [firstboot](recon/firstboot-2026-11-02.md), 2026-11-02-2; [gpu](recon/gpu-2026-11-03.md), 2026-11-03-5 | stock boots once the stick is out |

## SoC: power, clocks, SCMI/cpufreq, idle, suspend

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| Every enabled DT node binds | works | mainline at a804c57 + patch 0002-0007 + board DTS + config fragments (mica-sync and others) | drivers in mainline; GMU driver FROMLIST (patches 0002-0006); mica DTS not sent | [unbound](recon/unbound-2026-11-04.md), 2026-11-03-35; [gmu-crypto](recon/gmu-crypto-2026-11-03.md), 2026-11-03-26 | `unbound=` 0: every interconnect and clock provider reaches `sync_state()`. A proxy, not a per-node bind check: a failed probe with no `sync_state()` consumer is not counted (the touchscreen's HID probe still fails `-22`) |
| SCMI cpufreq (CPUCP mailbox) | works | mainline at a804c57 + board DTS (1000 ms window, ADR 0009) + config fragment (mica-scmi) | driver in mainline; window and ADR 0009 not sent | [scmi](recon/scmi-2026-11-03.md), 2026-11-03-8, 2026-11-04-4; [ADR 0009](adr/0009-no-psci-cpuidle.md) | 3 clusters, 710 MHz-3.42 GHz; 0 of 17 boots stalled without PSCI cpuidle; the window is unverified |
| SCMI after a warm reset from stock | works | mainline at a804c57 + board DTS (1000 ms window, ADR 0009) + config fragment (mica-scmi) | driver in mainline; window and ADR 0009 not sent | [scmi](recon/scmi-2026-11-03.md), 2026-11-03-9, -11; attempt 2026-11-04-13 | 1 of 1 warm reset on the current tree (Restart from stock; `record`: warm, AP reset in S0 with no G3->S5): firmware 0x20000, cpufreq 3 of 3, 0 timeouts, replies 0.1 ms. On 2026-11-03 2 of 2 warm resets failed (-110) with the 30 ms window and PSCI cpuidle on; which change fixed it is not separated (*inference*: ADR 0009 or the window) |
| CPU idle | partial | board DTS (ADR 0009) | LOCAL DTS deviation; stall report drafted, not sent | [scmi](recon/scmi-2026-11-03.md), 2026-11-04-3, -4; [ADR 0009](adr/0009-no-psci-cpuidle.md) | a deliberate deviation (ADR 0009, accepted): PSCI cpuidle is off and cores idle in WFI; with it on, SCMI replies stalled up to 1 s; the revisit is open, since idle and suspend power are unmeasured (*inference*: partial) |
| s2idle round trip | works | mainline at a804c57 + patch 0008 + patch 0009 + board DTS + config fragment (mica-ec, mica-pcie) | 0008 FROMLIST (LKML 2026-01-02); 0009 LOCAL, not sent | [suspend](recon/suspend-2026-11-04.md), 2026-11-04-11 (3 boots) | 3 of 3 cold boots, against 0 of 7 before 0009; test images (`gbook.suspend=1`); which low-power state was reached is unmeasured |
| Wake from s2idle: EC RTC alarm | works | mainline at a804c57 + board DTS + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | [suspend](recon/suspend-2026-11-04.md), 2026-11-04-5, -11 | `rtc0` is `cros-ec-rtc`; `suspend-wakeup` stays empty, so no wakeup source counted the wake |
| Wake from s2idle by keyboard | partial | mainline at a804c57 + patch 0008 + patch 0009 + board DTS + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | attempts 2026-11-04-14, -15 | every s2idle wake seen came on the EC interrupt (`msmgpio 66 chromeos-ec`, IRQ 181). On -15's second boot, space woke it 7.1 s into s2idle and it resumed (rc 0, about 13 s of resume). On -15's first boot, space did not wake it, and a power-button tap then left it powered off (no netlog, no SuzyQ, ramoops lost). On -14, an EC event woke it after 18.7 s with no key pressed. Lid and power-button wake untested |
| RTC (`cros-ec-rtc`, `rtc0`) | works | mainline at a804c57 + board DTS + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | [ec](recon/ec-2026-11-03.md), 2026-11-03-14; [suspend](recon/suspend-2026-11-04.md); 2026-11-04-12 | its alarm woke every suspend test. It counts through power-off: 242 s on the RTC against 240 s on the build host between two 2026-11-04-12 boots, with G3 between them (netlog `rtc-at-send` against the file's write time). It is not set to real time: it reads 1970-01-19 |

## Storage and buses: USB, Type-C, PCIe, NVMe

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| USB 2 host, all four controllers | works | mainline at a804c57 + board DTS + config fragment (mica-usb) | drivers in mainline; mica DTS not sent | [usb](recon/usb-2026-11-02.md), 2026-11-02-3 | webcam, FPMCU and the stick enumerate |
| USB 3, right port | works | mainline at a804c57 + board DTS + config fragment (mica-usb, mica-adsp) | drivers in mainline; mica DTS not sent | [usb](recon/usb-2026-11-02.md), 2026-11-02-5; [dp](recon/dp-2026-11-03.md), 2026-11-03-6 | 5000M; needs the ADSP for `pmic_glink`; runs alongside DP |
| USB 3, left port | untested | — | — | [usb](recon/usb-2026-11-02.md) | **parked until a session without the SuzyQ in the left port** (owner, 2026-11-04 park round); the SuzyQ sits there; no device tested |
| Type-C ports (UCSI over `pmic_glink`) | works | mainline at a804c57 + board DTS + config fragment (mica-usb, mica-adsp) | drivers in mainline; mica DTS not sent | [usb](recon/usb-2026-11-02.md), 2026-11-02-5; [dp](recon/dp-2026-11-03.md), 2026-11-03-6 | 2 ports, roles read; every read so far shows `orientation=normal`; `connector@0` is the left port |
| PCIe, both controllers | works | mainline at a804c57 + board DTS + config fragment (mica-pcie) | drivers in mainline; mica DTS not sent | [pcie](recon/pcie-2026-11-02.md), 2026-11-02-6 | Gen4 x4 (NVMe) and Gen3 x2 (WCN7850) link up |
| NVMe SSD (driver, I/O) | untested | — | driver in mainline | [pcie](recon/pcie-2026-11-02.md), 2026-11-02-6 | **parked until the spare SSD (M4, [ADR 0002](adr/0002-experiment-on-spare-ssd.md))** (owner, 2026-11-04 park round); enumerates; the driver is held out (`# forbid-y`) until the owner approves a read-only step |

## Network: Wi-Fi, Bluetooth

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| Wi-Fi (WCN7850, ath12k) | works | mainline at a804c57 + board DTS + config fragment (mica-pcie) | driver, firmware and board data in mainline and linux-firmware; mica DTS not sent | [wifi](recon/wifi-2026-11-03.md), 2026-11-03-1, -2 | 6 GHz at 320 MHz EHT, DHCP, ping; relinks after s2idle ([suspend](recon/suspend-2026-11-04.md)) |
| Bluetooth (WCN7850 on `uart14`) | works | mainline at a804c57 + board DTS + config fragment (mica-bt) + firmware (linux-firmware `qca/hmtbtfw20.tlv`, `hmtnv20.b112`) | drivers and firmware in mainline and linux-firmware; mica DTS not sent | attempt 2026-11-04-14 (netlog) | `hci_uart_qca` binds, `hci0` registers, setup completes (BTFW.HAMILTON.2.0.1, board id 0x112); no userspace, so no scan or pairing was tried. In s2idle something woke the system after 18.7 s from IRQ 181, possibly Bluetooth (*inference*) |

## Display and GPU

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| eDP panel (LG LP134WQ, 2560x1600) | works | mainline at a804c57 + patch 0001 + board DTS + config fragment (mica-display) | driver in mainline; panel entry LOCAL patch 0001, not sent; mica DTS not sent | [display](recon/display-2026-11-03.md), 2026-11-03-4; [panel-edp](recon/panel-edp-2026-11-03.md), 2026-11-03-9 | without 0001 it runs on conservative timings; 0001's delays do not come from a datasheet |
| Backlight (PWM on the LPG) | works | mainline at a804c57 + board DTS + config fragment (mica-display) | drivers in mainline; mica DTS not sent | [display](recon/display-2026-11-03.md), 2026-11-03-4; 2026-11-04-12 (3 boots) | set to 1023 and read back 1023, then restored to 2048, in 3 of 3 base-image boots (2026-11-04-12) |
| DP alt mode, right port (`connector@1`) | works | mainline at a804c57 + board DTS + config fragment (mica-usb, mica-adsp, mica-display) | drivers in mainline; mica DTS not sent | [dp](recon/dp-2026-11-03.md), 2026-11-03-6 | a 1920x720 monitor on `DP-2`, with USB 3 alongside |
| DP alt mode, left port (`connector@0`) | untested | — | — | [dp](recon/dp-2026-11-03.md) | **parked until a session without the SuzyQ in the left port** (owner, 2026-11-04 park round); needs the SuzyQ out, so netlog only |
| GPU probe (Adreno X1-85) | works | mainline at a804c57 + board DTS + config fragment (mica-gpu) | driver and firmware in mainline and linux-firmware; mica DTS not sent | [gpu](recon/gpu-2026-11-03.md), 2026-11-03-5; [gmu-crypto](recon/gmu-crypto-2026-11-03.md), 2026-11-03-26 (with 0002-0007) | SQE and GMU firmware load; zap off under EL2; `msm.separate_gpu_kms=1`; no rendering test |
| GMU driver binding | works | mainline at a804c57 + patch 0002-0007 + board DTS + config fragment (mica-gpu) | FROMLIST (patches 0002-0006: v1 of "drm/msm: Attach a driver to GMU", superseded by v2 on 2026-10-30); 0007 LOCAL (Omarchy's fix-up, not ours to send) | [gmu-crypto](recon/gmu-crypto-2026-11-03.md), 2026-11-03-26 | `bound 3d6a000.gmu`; the GMU left the `unbound=` list |

## Input and EC

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| ChromeOS EC (`cros-ec-spi`) | works | mainline at a804c57 + board DTS (GPIO chip-select) + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | [ec](recon/ec-2026-11-03.md), 2026-11-03-14 | the hardware chip-select gave garbage (attempt 2026-11-03-13, error -28) |
| Built-in keyboard | works | mainline at a804c57 + board DTS + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | [ec](recon/ec-2026-11-03.md), 2026-11-03-14 | 389 events in 20 s; layout, Fn and top-row keys not checked |
| Keyboard backlight | works | mainline at a804c57 + board DTS + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | [ec](recon/ec-2026-11-03.md), 2026-11-03-14 | 0 and 100 set and read back; the owner saw it light |
| Touchpad (I2C HID) | works | mainline at a804c57 + board DTS + config fragment (mica-touch) | drivers in mainline; mica DTS not sent | [touch-tpm](recon/touch-tpm-2026-11-03.md), 2026-11-03-16 | 15554 events in 30 s |
| Touchscreen (I2C HID) | broken | — | driver in mainline; cause unknown | [touch-tpm](recon/touch-tpm-2026-11-03.md), 2026-11-03-15 to 2026-11-04-2; 2026-11-04-12 | **parked until a new touch lead** (owner, 2026-11-03): reads turn to `0xff` partway through; the DT matches stock. On 2026-11-04-12 it probed in 1 of 3 boots (2731 events from `event4` while touched, IRQ 202 from 1 to 377) and failed `-22` in the other two |
| Fans | partial | mainline at a804c57 + board DTS (EC on spi13) + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | [ec](recon/ec-2026-11-03.md), 2026-11-03-14 | EC hwmon reads 2 fans at 0 RPM (idle); the EC drives them; never seen spinning (*inference*: partial) |
| Battery reporting | partial | mainline at a804c57 + board DTS + config fragment (mica-adsp) | drivers in mainline; ADSP firmware not in linux-firmware | [usb](recon/usb-2026-11-02.md), 2026-11-02-5; [suspend](recon/suspend-2026-11-04.md), 2026-11-04-11 | capacity has never been read: empty at 2026-11-02-5 and in every 2026-11-04 netlog capture; status reads `Charging` or `Not charging`; `power_now` sign unchecked (*inference*: partial) |
| Lid switch | untested | — | — | none | **parked until a stock-tree or EC lead** (owner, 2026-11-04 park round); no lid GPIO in the stock tree ([dts/README.md](../dts/README.md)) |
| Power button and EC buttons (`cros_ec_buttons`) | works | mainline at a804c57 + board DTS + config fragment (mica-ec) | drivers in mainline; mica DTS not sent | [ec](recon/ec-2026-11-03.md), 2026-11-03-14; 2026-11-04-12 | one brief press gave 4 and 6 events (`ec-buttons`, `event3`) in two 2026-11-04-12 boots; the third had no press. What a press does without userspace is untested |
| Ambient-light sensor | untested | — | — | none | **parked until a stock-tree or EC lead** (owner, 2026-11-04 park round); not described in the DTS ([dts/README.md](../dts/README.md)) |
| Glowbar (lid light) | untested | — | — | none | **parked until a stock-tree or EC lead** (owner, 2026-11-04 park round); not described in the DTS ([dts/README.md](../dts/README.md)) |

## Security

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| TPM (Ti50, `cr50_i2c`) | works | mainline at a804c57 + board DTS + config fragment (mica-tpm) | driver in mainline; mica DTS not sent | [touch-tpm](recon/touch-tpm-2026-11-03.md), 2026-11-03-15 | `tpm0` and `tpm-rng-0`; probe traffic only (`TCG_TPM2_HMAC` kept out) |
| Crypto engine (QCE) | broken | — | QCE depends on `BROKEN` at the pin | [gmu-crypto](recon/gmu-crypto-2026-11-03.md), 2026-11-03-26 | **parked until upstream drops `BROKEN` for QCE** (owner, 2026-11-04 park round); node disabled in the board DTS (Omarchy `2210`); not parked by the owner |

## Remoteprocs

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| ADSP | works | mainline at a804c57 + board DTS (`mica-el2.fixups`) + config fragment (mica-adsp) | driver in mainline; stock firmware not in linux-firmware; mica DTS not sent | [usb](recon/usb-2026-11-02.md), 2026-11-02-5 | stock `modem_a` firmware; its start waits 5 s on the CDSP's SSCTL reply ([cdsp](recon/cdsp-2026-11-03.md)) |
| CDSP | works | mainline at a804c57 + board DTS (`mica-el2.fixups`) + config fragment (mica-adsp) | driver in mainline; stock firmware not in linux-firmware; mica DTS not sent | [cdsp](recon/cdsp-2026-11-03.md), 2026-11-03-7 | still running at about 130 s; FastRPC is `=m`, so nothing uses it yet |

## Multimedia

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| Speakers | works | base image `bc62c69e…` (`v2026.11.05`, the sound node in the board DTS; proven first on the TEST IMAGE with `dts/diag/sound.dtsi`), kernel #35: all four units play and survive the SoundWire masters' runtime PM wakes with local patches 0011 (WSA884x `clk_stop_mode1`) and 0010 (boot 6 of 2026-11-05: tones a minute apart, a tone after 10 minutes idle, the four names heard); in the board DTS since 2026-11-05 (`9d120a5`) | no (M5 hold) | [audio-2026-11-04.md](recon/audio-2026-11-04.md): `aplay -l` card 0 `X1E80100-Dell-XPS-13-9345`, playback device 1; 2026-11-05-1 with both masters' `power/control=on`: the owner heard "front left, front right, rear right, rear left"; without it the clock-stop exit loses the re-enumeration by chance (two units on -28, none at 69.9 s on -1) | `kernel/mica-audio.config` (`RESET_GPIO=y`, `GPIO_SHARED_PROXY=y`, attempts -26 and -27); ticket 16 closed 2026-11-05 (the udev rule was not a workaround and is gone; patches 0011 and 0010); the node is in the board DTS; released as `v2026.11.05` on 2026-11-05 (attempt 2026-11-05-5: 3 clean cold boots, the four names heard on each) |
| Microphones | works | the same image, boot 7 of 2026-11-05: `arecord` on capture device 3 (UCM `Mic`) recorded the owner's voice and the playback was heard | no (M5 hold) | [audio-2026-11-04.md](recon/audio-2026-11-04.md), "The capture test": the owner heard the playback (9:26 AM EST); the file's RMS varies second by second | mic rail `EN_PP3300_MIC` (TLMM 69, stock overlay) as the VA macro's `vdd-micb-supply`, the DMIC rate the Yoga's (`dts/README.md`, "Unverified"); in the board DTS since 2026-11-05 |
| Headphone output | untested | — | — | none | **parked until M3** (owner, 2026-11-04 park round); the stock tree disables the WCD938x headset codec ([9345 diff](research/9345-dts-diff.md)); whether mica has a jack is not confirmed |
| Camera | untested | — | — | [usb](recon/usb-2026-11-02.md), 2026-11-02-3 | **parked until M3** (owner, 2026-11-04 park round); the USB webcam `1bcf:28dc` enumerates on `usb_2`; no capture tried |
| Fingerprint | untested | — | — | [usb](recon/usb-2026-11-02.md), 2026-11-02-3 | **parked until M3** (owner, 2026-11-04 park round); the FPMCU `18d1:5406` enumerates on `usb_mp`; nothing more tried |

## Power

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| Idle power | untested | — | — | [suspend](recon/suspend-2026-11-04.md) | **parked until a battery-only power session** (owner, 2026-11-04 park round); unmeasured, because the SuzyQ powers the bench; [ADR 0009](adr/0009-no-psci-cpuidle.md) raises it by an unknown amount |
| Suspend power | untested | — | — | [suspend](recon/suspend-2026-11-04.md), 2026-11-04-11 | **parked until a battery-only power session** (owner, 2026-11-04 park round); unmeasured; the battery reads as charging on the bench |
| Deep suspend (`mem_sleep=deep`) | broken | — | — | attempt 2026-11-04-16 (AP and EC consoles, ramoops) | **parked until a debug boot with `no_console_suspend`** (owner, 2026-11-04 park round: a failed test may be parked). `mem` with `mem_sleep=deep`: the EC saw the AP sleep ("Handle sleep: 1", EC 145.3 s), then "AP_RST_L transitions not expected" (152.3 s, about 7 s in, before the 20 s alarm) and a host reboot. The kernel log stops at "Suspending console(s)" (136.0 s) |

## Userspace

| Feature | State | Where it works | Upstream | Evidence | Note |
| --- | --- | --- | --- | --- | --- |
| Initramfs (busybox `/init`) | works | n/a (gbook `kernel/initramfs/init`) | n/a | [firstboot](recon/firstboot-2026-11-02.md), 2026-11-02-2 | captures, then reboots to stock; loads no modules |
| Rootfs from USB | works | board DTS + `kernel/initramfs/init` (switch_root) + the M3 rootfs (`scripts/build-rootfs.sh`) | n/a | [rootfs](recon/rootfs-2026-11-04.md), 2026-11-04-18, -19; release boots -21 to -23; fast sweep -24 (`m3-end` 74 s); rootfs side -25 (`m3-end` 49 s, cage 37.8 s) | Debian sid arm64 from the stick's partition 2 (`gbook-root`): `/init` finds it by `kern_guid`, systemd boots, Wi-Fi joins in userspace (wpa_supplicant, networkd DHCP), Ghostty 1.4.0 runs under cage on the panel; the rootfs sends its netlog and journal over that link, and the build host reaches it by key-only ssh (ADR 0012 update) |
| Mesa (freedreno) | works | mainline at a804c57 + patch 0002-0007 + the M3 rootfs (Mesa 26.2.6-1) | drivers in mainline; GMU driver FROMLIST | [rootfs](recon/rootfs-2026-11-04.md), 2026-11-04-18, -19; release boots -21 to -23 | `eglinfo`: OpenGL 4.6 Core on "Adreno X1-85"; kmscube on the display card (`card2`) exit 0, renderer Adreno X1-85; cage's wlroots renderer "Adreno X1-85", GLES 3.2; Vulkan on Turnip: `vkcube` through cage's Wayland socket selected "Adreno X1-85" and rendered (boot 3) |

## Milestone M2: where it stands

**M2 is done (2026-11-04, 12:38 PM ET):** all four criteria are met. Criterion 1 is met by the `unbound=` proxy, and the s2idle row's boots ran on test images.

M2 is "board on the console" in [ADR 0010](adr/0010-milestones-status-upstream-hold.md), from the
[milestones note](research/milestones-versioning.md), section 4. The ADR's bar has four criteria:
1. every enabled DT node binds;
2. the M2 rows read `works`: USB host, Type-C, PCIe enumeration, Wi-Fi, eDP + backlight, GPU probe, EC keyboard,
   touchpad, TPM, SCMI cpufreq and the s2idle round trip;
3. every other row reads `works` or `partial`, or is parked with a note;
4. one base image (no debug command-line or DT extras) has 3 clean cold boots by `scripts/attempt.sh tally`.

| Criterion | Met? | Why |
| --- | --- | --- |
| 1. Every enabled DT node binds | met (by proxy) | measured by `unbound=` (no `sync_state() pending` line), not per node: 0 since attempt 2026-11-03-35 ([unbound](recon/unbound-2026-11-04.md)), and `unbound=0` in the health column of every 2026-11-04 row of `dumps/firstboot/attempts.tsv` |
| 2. The M2 rows read `works` | met | all twelve; the backlight was set and read back in 3 of 3 base-image boots (2026-11-04-12). The s2idle row's boots ran on test images (`gbook.suspend=1`) |
| 3. Every other row is `works`, `partial` or parked | met | Bluetooth works; keyboard wake from s2idle is partial (1 of 2); deep suspend failed and is parked (a reset about 7 s into deep sleep); 16 more rows are parked (owner, 2026-11-04 park round), and the touchscreen was parked on 2026-11-03 after three boots: 18 parked rows in all |
| 4. A base image with 3 clean cold boots | met | attempt 2026-11-04-12, kernel #26 (`7.3.0-gbook-gf12f3f6-ga804c5742bff-dirty`), `attempt.sh stick`: base image; 3 cold boots, 3 clean (below) |

Under criterion 3, rootfs, Mesa and the audio state are also M3 criteria in the ladder (section 4).

Counts (checked by `scripts/status_check.py`): 55 rows: 36 works, 5 partial, 3 broken, 11 untested; 14 parked.
The line above is the one `scripts/check.sh` compares with the tables (retro-8/06), so it changes with them.

Criterion 4, read-only from `dumps/firstboot/attempts.tsv` (gitignored), at 11:24 AM ET:

```
$ scripts/attempt.sh tally '^2026-11-04-12$'
group 1 /^2026-11-04-12$/: attempts=1 health=1 boots=3 known=3 stalled=0 clean=3 unknown=0 max=0.1-0.1ms
  2026-11-04-12 0/3
```

- **The base image:** packaged with no command-line or DT extras; `attempt.sh verify` recorded "base image: no
  command-line or DT extras" and image sha256 `2f08fb87463eeac6`. All three boots started cold (EC `G3->S5`).
- **What "clean" means:** in `tally`, "clean" is an SCMI verdict: no timeout, and every reply under 100 ms
  (`scripts/boot_health.py`). It does not judge the whole boot.
- **Before 2026-11-04-12** the only row with 0008 + 0009 was `2026-11-04-11`, a test image (`gbook.suspend=1`).
- **Next:** M3, userspace from USB (a rootfs with Mesa, [ADR 0010](adr/0010-milestones-status-upstream-hold.md)).
