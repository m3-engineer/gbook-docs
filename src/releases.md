# Releases

One entry per annotated tag `vYYYY.0M.0D[.MICRO]` (decision 0011); the tag message is the release note.

## `v2026.11.05`

```
v2026.11.05: M3

Milestone: M3 (ADR 0010)
Kernel base: torvalds a804c57 (v7.3 + 1703, the 7.4 merge window; ADR 0011)
Kernel release: 7.3.0-gbook-2026.11.04-35-g7c6a1aa-ga804c5742bff-dirty (uname -r; build 69edd54 of gbook)
Local patches (kernel/patches/, ADR 0007):
  0001-drm-panel-edp-add-lgd-0x0804.patch: LOCAL gbook (not sent: the EDID gives only part of the model name), checked 2026-11-04
  0002-drm-msm-a6xx-cxpd-device-link-stateless.patch: FROMLIST [RFT 1/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-1-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 2/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0003-drm-msm-centralize-standalone-drm-check.patch: FROMLIST [RFT 2/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-2-6e33e6aa9b4f@oss.qualcomm.com>; dropped in v2 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0004-drm-msm-adreno-fix-drvdata-typecast.patch: FROMLIST [RFT 3/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-3-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 1/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0005-drm-msm-component-model-for-standalone-gpu.patch: FROMLIST [RFT 4/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-4-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 5/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0006-drm-msm-attach-a-driver-to-the-gmu.patch: FROMLIST [RFT 5/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-5-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 6/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below), ported to v7.2.8 by Brandon Williams; checked 2026-11-04
  0007-drm-msm-gmu-optional-and-lock-init.patch: LOCAL Brandon Williams via Omarchy (third-party fix-up on 0002-0006), https://github.com/omacom/omarchy-pkgs/tree/master/pkgbuilds/linux-omarchy-aarch64, checked 2026-11-04
  0008-clk-qcom-gcc-x1e80100-pcie-gdsc-retention.patch: FROMLIST [6/7] (Krishna Chaitanya Chundru) <20260102-pci_gdsc_fix-v1-6-b17ed3d175bc@oss.qualcomm.com>, changes requested on linux-arm-msm patchwork; regenerated against a804c57; checked 2026-11-04
  0009-clk-qcom-gcc-x1e80100-pcie-phy-gdsc-retention.patch: LOCAL gbook (ours; not sent: upstream hold until M5), checked 2026-11-04
  0010-soundwire-qcom-rearm-enumerator-after-clock-stop.patch: LOCAL gbook (ours; not sent: upstream hold until M5), checked 2026-11-05
  0011-asoc-wsa884x-clk-stop-mode1.patch: LOCAL gbook (ours; not sent: upstream hold until M5), checked 2026-11-05
KERN-A image sha256 (attempt.sh stick): bc62c69ecf560525
Rootfs image sha256: 6fea12f2dc824f63947e7251fafd31ae799f44ea6c5e40056ebaddba0f72ac56
Rootfs snapshot: 20261104T000000Z (snapshot.debian.org); lock list sha256 12f96fa08768262e228319783831fa28bd229d9e821b2b5bdfd8be2d02cc1388; 321 packages
Proof (attempt.sh tally '^2026-11-05-5$'): group 1 /^2026-11-05-5$/: attempts=1 health=1 boots=3 known=3 stalled=0 clean=3 unknown=0 max=0.1-0.1ms
Attempts: 2026-11-05-5; start: cold
Changes since v2026.11.04: 45 commit(s)
  69edd54 Release bar met for v2026.11.05: base image bc62c69e (sound node in the board DTS), 3 clean cold boots, the names heard on each
  e4820b0 Audio: the capture test passes (the owner heard the recording played back); Microphones: works; boot 7 added to 2026-11-05-4
  9d120a5 Audio: the sound node moves from dts/diag/sound.dtsi into the board DTS (mapping and unverified values in dts/README.md)
  176058d Retro 15: check.sh -q, mkpatch.sh, localversion on the kernel's inputs, watch replaces and wait-rootfs, attempt lifecycle in CLAUDE.md, audio-state --names
  b9c6ca2 Audio: ticket 16 closed (the owner heard the idle tone and the four names); Speakers works; README resume line
  b93bd13 Audio: the rule-free boot meets ticket 16's bar (tones a minute apart, after 10 minutes idle, the four names)
  86d6fd2 Ticket 16: tone 3 of boot -4 has no hearing report; audio-state.sh's masters label is stale
  e7c2791 Audio: the udev rule leaves the rootfs (patches 0011 and 0010 fix the wakes); check 45 now refuses it; status row for the speakers
  9a61e0b Audio: boot 2026-11-05-4 recorded, patch 0011 with 0010 revision 3 passes the first bar (three wakes whole)
  c08dc60 Audio: boot 2026-11-05-3 recorded (revision 2 sees the stall, the re-arm does not clear it)
  7c6a1aa Audio: patch 0010 revision 3 (a wedged enumerator gets a controller reset and init) and patch 0011 (wsa884x clk_stop_mode1)
  ed3af1e Audio: boot 2026-11-05-2 recorded (patch 0010 revision 1 did not fire); ideas #29 and #30 on the task list
  d4c3b68 Audio: patch 0010 revision 2, a delayed check re-arms the enumerator while a peripheral sits at device 0 (ticket 16)
  22ffd5c Audio: the udev rule is not a workaround (its write is the first wake, bus 1 lost it); attempt 2026-11-05-2 opened for patch 0010
  50d16d2 Research sources: CodeLinaro through its GitLab API, patchwork and GitHub commits API for upstream-fix reads
  4921d2f Audio: ticket 16 comment, recon Next and log row for patch 0010 and the udev-rule rootfs build
  50ac603 Audio: local patch 0010, re-arm the SoundWire enumerator when re-enumeration stalls after clock stop (ticket 16)
  ffb7273 Retro 14: recon.sh stock-kmsg, audio-state UCM path and masters runtime PM, sdw status caveat, Next pruned
  f9b770d Audio: all four speakers play with the SoundWire masters kept clocked (boot 2026-11-05-1); udev workaround, ticket 16 fix shape
  c23ab29 Retro 13: gaps check reads reset-gpios and shared GPIOs; audio-state, swrm_enum, mica-ssh; one watch at a time
  dbfd2ef Research: ASoC and SoundWire debugging tools (ticket 16 reads)
  7f9fe97 Audio: speaker test, the left amplifiers never enumerate (ticket 16); ssh user joins audio
  9b8fc6b Audio: the sound card binds (attempts 2026-11-04-26 to -28)
  c613c1d mica-audio.config: GPIO_SHARED_PROXY=y (the shared reset pins, attempt -27)
  e8c45c0 mica-audio.config: RESET_GPIO=y (the codecs deferred on their reset-gpios, attempt -26)
  afca45f Retro 12: stock tree is two files, + kernel release refused at the bar, navigation lines
  a7d9d52 Log: the audio offline part; attempts row 2026-11-04-26
  c80b1a3 sound.dtsi: the DMIC supply from the stock overlay (EN_PP3300_MIC, TLMM 69)
  7f5199a Audio attempt, offline part (M3 ticket 10)
  7072998 Log: retro 11 done but ticket 03 (RTK.md, owner); README next line
  752eb8b Retro-11 tickets 02, 04, 05 and retro-9 07: journal group, tally pending row, Evidence column, the ssh block
  a71c205 watch: classify the EC power sequence (retro-11/01)
  ca9cb6f Retro 11: five tickets for the rootfs-side session
  4ec4dae Docs: the EC's G3->S5 after power-down is soft-off; Ghostty's 38 s marked inferred
  e085d11 Log: boot -25 powered off over ssh
  8079c55 Docs: the rootfs side measured, m3-end at 48.7 s (attempt 2026-11-04-25)
  e6d0e06 rootfs: cage at boot, polled cage read, joined channel handed over (task #26)
  82549ae Recon: the rootfs side of boot 2026-11-04-24, by the journal
  54d6e82 Log: the fast-sweep boot powered off over ssh
  a5ab9d2 Docs: the fast-sweep boot is still up; times from logged anchors
  ... and 5 more
```

## `v2026.11.04`

```
v2026.11.04: M3

Milestone: M3 (ADR 0010)
Kernel base: torvalds a804c57 (v7.3 + 1703, the 7.4 merge window; ADR 0011)
Kernel release: 7.3.0-gbook-g82c43ed-ga804c5742bff-dirty (uname -r; build 506159b of gbook)
Local patches (kernel/patches/, ADR 0007):
  0001-drm-panel-edp-add-lgd-0x0804.patch: LOCAL gbook (not sent: the EDID gives only part of the model name), checked 2026-11-04
  0002-drm-msm-a6xx-cxpd-device-link-stateless.patch: FROMLIST [RFT 1/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-1-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 2/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0003-drm-msm-centralize-standalone-drm-check.patch: FROMLIST [RFT 2/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-2-6e33e6aa9b4f@oss.qualcomm.com>; dropped in v2 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0004-drm-msm-adreno-fix-drvdata-typecast.patch: FROMLIST [RFT 3/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-3-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 1/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0005-drm-msm-component-model-for-standalone-gpu.patch: FROMLIST [RFT 4/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-4-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 5/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below); checked 2026-11-04
  0006-drm-msm-attach-a-driver-to-the-gmu.patch: FROMLIST [RFT 5/5] of "drm/msm: Attach a driver to GMU" v1 (Akhil P Oommen) <20260513-gmu-sync-state-fix-v1-5-6e33e6aa9b4f@oss.qualcomm.com>; v2 has it as 6/8 <20261030-gmu-sync-state-fix-v2-0-89d3082d97af@oss.qualcomm.com>; copy: Omarchy linux-omarchy-aarch64 (below), ported to v7.2.8 by Brandon Williams; checked 2026-11-04
  0007-drm-msm-gmu-optional-and-lock-init.patch: LOCAL Brandon Williams via Omarchy (third-party fix-up on 0002-0006), https://github.com/omacom/omarchy-pkgs/tree/master/pkgbuilds/linux-omarchy-aarch64, checked 2026-11-04
  0008-clk-qcom-gcc-x1e80100-pcie-gdsc-retention.patch: FROMLIST [6/7] (Krishna Chaitanya Chundru) <20260102-pci_gdsc_fix-v1-6-b17ed3d175bc@oss.qualcomm.com>, changes requested on linux-arm-msm patchwork; regenerated against a804c57; checked 2026-11-04
  0009-clk-qcom-gcc-x1e80100-pcie-phy-gdsc-retention.patch: LOCAL gbook (ours; not sent: upstream hold until M5), checked 2026-11-04
KERN-A image sha256 (attempt.sh stick): 9673d6d782ef4cdb
Rootfs image sha256: 4b0e2e027c0b2d74699eaa907a0eaca8597504a9eab6caec394b28c6f15c5d3c
Rootfs snapshot: 20261104T000000Z (snapshot.debian.org); lock list sha256 12f96fa08768262e228319783831fa28bd229d9e821b2b5bdfd8be2d02cc1388; 321 packages
Proof (attempt.sh tally '^2026-11-04-2[123]$'): group 1 /^2026-11-04-2[123]$/: attempts=3 health=3 boots=3 known=3 stalled=0 clean=3 unknown=0 max=0.1-0.1ms
Attempts: 2026-11-04-21 2026-11-04-22 2026-11-04-23; start: cold,cold,cold
Changes since the first commit (first release): 256 commit(s)
  506159b M3 release bar met: snapshot rootfs on ROOT, 3 clean cold boots; release-draft.sh fixes
  0d297ff Log: the snapshot-pinned release rootfs built (20261104T000000Z, 321 packages)
  07885c4 Retro-9/01: ROOT write and read-back as attempt.sh root-cmd and root-verify
  8b5181a Docs: README resume, docs index, glossary and ADR 0010 updated for the first ROOT boots
  4f59c59 Retro-9/02 resolved: udiskie honours the sticks' no-automount hint
  584702c Retro 9: tickets for the ROOT-boot session's tooling gaps
  d21096d Third ROOT boot: ssh from the build host, the netlog with the journal, Vulkan
  6fe07af M3 ticket 13: sshd for the build host in the rootfs, keys handed over at boot
  575493b Research: how the build host reaches the booted rootfs (sshd, reverse ssh, journal, USB gadget)
  e11ae23 The rootfs boots from USB: Mesa on the GPU, Wi-Fi in userspace, Ghostty
  b9514cc Ticket 09: note the terminfo symlink for the next rebuild
  a2dee5a M3 ticket 12: release-draft.sh checks the bar and drafts the tag message
  879a770 M3 ticket 09: Ghostty under cage in the rootfs
  1e0ebb5 M3 ticket 07: the rootfs's units and the M3 captures
  d8123c7 Rootfs: offline mode from the .deb cache, and byte-identical builds
  5e3956f M3 ticket 08: Ghostty 1.4.0 built for arm64 by cross compilation
  ebd263f Research: pinned, reproducible rootfs builds when snapshot throttles
  acfbcf4 M3 ticket 05: /init finds ROOT and switch_roots into it
  be3091b Portable checks and an honest manifest for a non-snapshot rootfs build
  98a9391 M3 ticket 03: build-rootfs.sh builds the rootfs reproducibly
  e95ebd4 Retro-7/08 resolved: stick boot tries counted and raised to 15
  61258b6 Retro-8/01 resolved: watch and verify say when a console tty is gone
  d2e8a94 Retro-8/04 resolved: known parked failures collapse in watch
  a9a53d4 Retro-8/06 resolved: a format check for docs/status.md
  4cf4b78 Retro-7/07 resolved: check 32 reads every added markdown line
  f9e2532 Retro-8/05 resolved: rootless podman for the rootfs sizing
  80064c8 Retro 8: tickets for the M2 bench session's tooling gaps
  148a2d7 M3 tickets 04 and 06 verified on attempt 2026-11-04-17
  82c43ed M3 tickets 04 and 06: ROOT in every image's GPT; one netlog sender
  d573942 M3 ticket 02: size the rootfs (1.45 GiB installed, 303 packages)
  f2bac5a M3 ticket 01 resolved: build #28 has FW_LOADER_USER_HELPER off, USB_UAS on
  f5cb508 M3 plan: ADR 0012 (Debian sid rootfs on the stick), 12 tickets
  139bcdc docs/research/sources.md: where the evidence comes from, how to read it
  ca3c851 Research: the M3 rootfs (Debian sid now, Omarchy aarch64 at M4)
  ce13a86 Milestone M2 reached; deep suspend resets the AP and is parked
  b97066c Keyboard wake from s2idle: partial (1 of 2), via the EC interrupt
  cfe5ed6 Bluetooth works (2026-11-04-14); capture the s2idle wake IRQ
  635448d Bluetooth for M2: mica-bt.config, QCA firmware, /init capture
  8ebbda3 /init suspend modes: key (wake by key, 120 s safety alarm) and deep
  48fc483 M2 park round: 16 rows parked, 3 tests left (wake, deep, Bluetooth)
  ... and 216 more
```

