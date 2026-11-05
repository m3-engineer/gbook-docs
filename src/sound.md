# Sound on mica

How the speakers and microphones of the Dell XPS Googlebook (board `mica`) came to work on mainline Linux.
[Status](docs/status.md) lists "Speakers" and "Microphones" as **works** on the released image `v2026.11.05`; the Nura
port's wiki lists Audio as Broken as of its 2026-10-31 edit (<https://wiki.nura.eco/wiki/Dell_XPS_Googlebook_(google-mica)>).
Sources: [the audio recon note](docs/recon/audio-2026-11-04.md), [the DT README](dts/README.md),
[the audio fragment](kernel/mica-audio.config), [the patch list](kernel/patches/README.md). The owner's hearing reports,
with their times, are the evidence that sound came out; the register reads say why.

## The hardware

The card is Qualcomm's `qcom,x1e80100-sndcard`, model `X1E80100-Dell-XPS-13-9345`, on the Low Power Audio Subsystem
(LPASS). Four WSA8845 smart amplifiers (Qualcomm's WSA family) sit on two MIPI SoundWire buses, two per bus; four digital
microphones (DMICs) hang off the voice-activation (VA) macro. The audio DSP's topology file loads at the card's probe, and
Debian's ALSA Use Case Manager (UCM) profile for the XPS 13 9345 resolves through a link the rootfs adds (audio recon
note, "Result").

| Part | Stock ChromeOS tree | Mainline | Pins and rails |
| --- | --- | --- | --- |
| Two WSA8845, SoundWire link 1 (`swr0`) | `wsa884x@02170220` SpkrLeft (unique id 0), `@02170221` SpkrRight (id 1), `wsa_swr_master` | `sdw:1:0:0217:0204:00:0`, `:1` | LPI gpio10/11; shared reset TLMM 204 |
| Two WSA8845, link 4 (`swr3`) | `@02170220` Spkr2Left, `@02170221` Spkr2Right, `wsa2_swr_master` | `sdw:4:0:0217:0204:00:0`, `:1` | LPI gpio15/16; shared reset TLMM 205 |
| Supplies | `vdd-1p8` = L15B | plus `vdd-io` = L12B | L12B unverified |
| Four DMICs, VA macro | `dmic01_default`, `dmic23_default` | LPI 6/7, 8/9 | `EN_PP3300_MIC`, TLMM 69, as `vdd-micb-supply` |
| PCM devices | | playback 1, capture 3 | UCM `Speaker`, `Mic` |

(audio recon note, "What the boots proved about the mapping"; DT README, "What changed from the 9345", row "Audio")

## Where the mapping came from

The node was modelled on the Lenovo Yoga Slim 7x tree at the pinned commit `a804c57`, then checked against the stock
ChromeOS tree from the public recovery image: the SoundWire masters and codecs, the shutdown pins, L15B, the VA macro and
the DMIC pins trace to the stock base tree, the microphone rail to the stock board overlay.
It booted as a TEST IMAGE from 2026-11-04, moved into the board DTS on 2026-11-05 and was proven on the base image over
three clean cold boots. One deviation: stock drives the shutdown pins high when active; mica starts them low, the Yoga's
way, and the codec driver's `reset-gpios` releases them; all four play that way (DT README, row "Audio").

## The two kernel options that blocked the card

The initramfs loads no modules, so [the audio fragment](kernel/mica-audio.config) builds in every driver the node needs;
all were `=m` in the arm64 defconfig (audio fragment, header). Two were not obvious. The WSA884x driver asks the reset framework for
its shutdown pin; the reset core turns `reset-gpios` into an auxiliary `reset-gpio` device and defers the codec until that
device's driver, `CONFIG_RESET_GPIO`, binds. With it built in (kernel #31) the `reset-gpio` devices deferred in turn: TLMM
204 and 205 are each shared by two codecs, and the kernel's shared-GPIO support routes such a pin through a proxy chip
that only `CONFIG_GPIO_SHARED_PROXY` registers. Both are `=y` since kernel #32, and the card bound on attempt
2026-11-04-28. A distribution kernel loads both as modules, so the Yoga never showed this (audio recon note, "The two
blockers, both kernel options").

## The first sound, and the wake problem

The speaker test on boot -28 (2026-11-04, 11:51 PM EST): the owner heard two sounds, one louder and one lower, and the
spoken names gave "Front Right" and "Rear Right"; after some minutes, nothing. The masters' enumerator registers showed
one enumerated slot per bus (unique id 1) and a slave stuck at device number 0. The note's reading (inferred): the
right-side units played, the id-0 pair never enumerated, and every re-enumeration after a clock stop failed the same way
(audio recon note, "The speaker test").

The debug boot (2026-11-05, 12:25 AM EST) showed all four amplifiers enumerating at boot, with the unique ids the DT says.
The exit from clock stop lost them: after the SoundWire masters runtime-suspend, each wake races the hardware enumerator
against the attach interrupts, bus by bus, and which bus wins is chance: both on the first wake, neither on the first
tone, one on the second; the owner heard nothing at either tone. With the masters' runtime power management forced on,
both buses re-enumerated and the owner heard "front left, front right, rear right, rear left" (audio recon note, "The
debug boot"). A udev rule forcing the masters on was rejected: its own write is the first wake, and on that boot (1:01 AM
EST) one bus lost the race and stayed lost (audio recon note, "The udev-rule boot").

## The fix: two local patches, one of them the fix

Both patches carry the same first line, quoted because the files stay unpublished until milestone M5 and
[the patch list](kernel/patches/README.md) gives them by status line only:

```
Status: LOCAL gbook (ours; not sent: upstream hold until M5), checked 2026-11-05
```

Patch 0010 re-arms a stalled SoundWire enumerator in Qualcomm's master driver (audio recon note, "The udev-rule boot").
Patch 0011 sets `clk_stop_mode1` on the WSA884x codec, so every resume of the masters runs the full reset-and-init sequence
that has enumerated at every boot, instead of the bare clock restart (audio recon note, "The patch boot, revision 3 and
patch 0011").

With both (kernel #35, 1:34 AM EST) three wakes came back whole, where two earlier revisions of 0010 alone had lost a bus
on the first; the owner heard all the beeps each time (same section). The rule-free boot (2:05 AM EST) met the ticket's
bar, a tone after ten minutes idle included (audio recon note, "The rule-free boot"). The 0011-alone boot (kernel #36,
12:32 PM EST) set 0010 aside and every wake came back whole; the owner heard tone 1, tone 2 and the four names twice (12:30
and 12:32 PM EST). So 0011 carries the fix; the owner decided at 12:38 PM EST that 0010 stays until the M5 patch review and
is then dropped (audio recon note, "The 0011-alone boot"). The released `v2026.11.05` is kernel #35, with both (status,
"Speakers").

## The microphones

The capture test (2026-11-05, 9:26 AM EST) enabled UCM's `Speaker` and `Mic`, recorded ten seconds from capture device 3
while the owner spoke, and played the file back through the speakers. The owner heard their own voice. The file, measured
on the build host, varies second by second on both channels; the journal has no VA macro, DMIC or LPASS line for the
capture. So the mic rail and the DMIC clock work as described (audio recon note, "The capture test").

## Boot by boot

| Date, time (EST) | Boot, kernel | Finding | Heard (owner) |
| --- | --- | --- | --- |
| 2026-11-04 | -26 #30, -27 #31 | codecs, then `reset-gpio` devices, deferred; no card | no test |
| 2026-11-04, 11:32 and 11:51 PM | -28, #32 | card 0 bound; speaker test: one slot per bus, then nothing | two sounds, then silence |
| 2026-11-05, 12:25 AM | -1, #32, debug | all four at boot; wakes lose buses by chance; masters on: all four | nothing, nothing, four names |
| 2026-11-05, 1:01 AM | -1, udev rule | the rule's write is the first wake; one bus lost | no tone |
| 2026-11-05, 1:34 AM | -4, #35, 0010 + 0011 | three wakes, all four back | all the beeps, three times |
| 2026-11-05, 2:05 AM | -4, #35, no rule | five wakes whole, one after 10 min idle | eight beeps; four names |
| 2026-11-05, 9:26 AM | boot 7, #35 | DMIC capture, played back | own voice |
| 2026-11-05, 12:32 PM | -6, #36, 0011 alone | every wake whole | two tones, four names twice |

(audio recon note, "Result" through "The 0011-alone boot")

## What is unverified

Audio values the DT README marks as not traced to the stock tree (DT README, "Unverified (check at first boot)"):

- `vdd-io-supply` L12B on the four codecs: not in the stock codec nodes; every `a804c57` X1E80100 board uses it.
- `qcom,dmic-sample-rate = <4800000>`: the Yoga's; stock sets only the clock divider 16.
- The 3.3 V `EN_PP3300_MIC` as `vdd-micb-supply`: the Yoga's is a 1.8 V LDO; the stock rail is always-on, so a wrong
  binding is harmless.
- Which physical unit each UCM prefix (`WooferLeft`, `TweeterLeft`, `WooferRight`, `TweeterRight`) drives: stock calls
  `swr0`'s pair SpkrLeft/SpkrRight and `swr3`'s Spkr2Left/Spkr2Right; open.

## What is left

A read FIFO underflow burst on every wake and two `Parity error detected` lines remain open; they did not stop playback
(audio recon note, "The debug boot"). PipeWire and WirePlumber are not yet in the rootfs; a per-card WirePlumber drop-in is
a recorded proposal for when they are ([SteamOS on ARM research note](docs/research/steamos-arm.md), "What gbook could
adopt").
