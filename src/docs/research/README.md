# Research notes

Where the evidence comes from and how to read each source (blocked sites and their mirrors, the APIs that work):
[`sources.md`](sources.md).

One file per topic, each claim with its source and the date it was read.

Done:

- [`chromeos-boot-path.md`](chromeos-boot-path.md) (2026-10-21): how Linux can boot through mica's depthcharge, fastboot, CCD, recovery image

- [`stock-dtb.md`](stock-dtb.md) (2026-10-21): the stock DT extracted from the recovery image, its hashes and board devices
- [`ccd-gsc.md`](ccd-gsc.md) (2026-10-21): SuzyQ on the left port, console map, GSC version and ccdstate, EC log
- [`9345-dts-diff.md`](9345-dts-diff.md) (2026-10-21): node-by-node against mainline 9345; AP console `uart21`; what to copy and what to replace
- [`el2-handoff.md`](el2-handoff.md) (2026-10-21): depthcharge enters the kernel at EL2 with no Gunyah; build the mica DTB with `x1-el2.dtso`
- [`fit-packaging.md`](fit-packaging.md) (2026-10-21): mkdepthcharge FIT + dev-key signing for mica, 256 MiB limit, cmdline, cgpt attributes, FIT matching, offline checks, tools on Arch
- [`console-kernel-config.md`](console-kernel-config.md) (2026-10-21): built-in drivers and boot arguments for a console-only first boot on `uart21`, earlycon limits, Image size, jhovold/jglathe/Ubuntu Concept configs
- [`silent-boot-observation.md`](silent-boot-observation.md) (2026-10-21): if the AP console is silent: depthcharge ramoops and its readback, the coreboot framebuffer, EC console, firmware log, LED codes, `ccdstate`

- [`scmi-cpucp-timeouts.md`](scmi-cpucp-timeouts.md) (2026-11-03): intermittent SCMI `timed out in resp` and `scmi-cpufreq -110` at boot; upstream fixes (all in the pin), the FastChannel quirk hazard on `0x0` firmware version, `arm,max-rx-timeout-ms`, measure-first plan
- [`milestones-versioning.md`](milestones-versioning.md) (2026-11-04): a milestone ladder M0-M7 over the gates, CalVer image tags, kernel `[PATCH vN]` rules and patch status words, when the upstream hold could end (AI agents may not add `Signed-off-by`); 9 open questions for the owner
- [`m3-rootfs.md`](m3-rootfs.md) (2026-11-04): which rootfs for M3 (Debian sid, Arch Linux ARM + Omarchy, Ubuntu, Fedora, postmarketOS: Mesa for the X1-85, Ghostty 1.4, our kernel, pinning) and how it boots: ROOT on the same stick, `/init` finds it by `kern_guid`, `switch_root`; 10 open questions for the owner
- [`debug-tools.md`](debug-tools.md) (2026-11-03): the per-boot debug tools: SCMI and I2C trace events, dyndbg, what each boot carries and how `attempt.sh trace` reads it
- [`rootfs-pinning.md`](rootfs-pinning.md) (2026-11-04): pinning and reproducing the M3 rootfs when snapshot.debian.org throttles
- `rootfs-access.md` (2026-11-04): reaching the booted rootfs from the build host without a secret in the image (keys in the initramfs, journal upload, ssh)
- [`asoc-debug-tools.md`](asoc-debug-tools.md) (2026-11-04): ASoC, SoundWire and audioreach debugging tools; the downstream driver's enumerator handling (ticket 16)
- `scmi-cpucp-stall-report.md` (2026-11-04): DRAFT report for linux-arm-msm on the PSCI-retention stall, not sent (M5 hold)
- [`steamos-arm.md`](steamos-arm.md) (2026-11-05): what Valve published for the Steam Frame (no ARM SteamOS tree; package repos, repair image, the Deckard DTS, kernel commits through GitHub), five adoption candidates and the owner's decisions
- [`m4-recovery-matrix.md`](m4-recovery-matrix.md) (2026-11-05): Valve's five recovery rows mapped onto mica's vboot and recovery-stick mechanisms, each labelled proven or inference; the three owner probes that close M4's return to stock; the slot-policy question
- `public-writeup.md` (2026-11-05): publishing gbook as a guide: the repo inventory and identifier exposure, Nura and aarch64-laptops conventions, Diátaxis, licences, venues with versions, a redaction gate; finds Anton Bambura's public Nura port of mica (DTS 2026-10-19, same compatible)
- `cloudflare.md` (2026-11-05): which Cloudflare products fit the chosen GitHub Pages setup: a DNS-only CNAME and the challenge TXT now, Web Analytics by snippet, R2 or GitHub Releases for the artefacts at the first release that has them, token permission names; Pages, Workers, Turnstile, Tunnel and rate limiting skipped with reasons; 6 open questions for the owner

Reading upstream (learned 2026-11-03, `scmi-cpucp-timeouts.md`):
- lore.kernel.org, patchwork and git.kernel.org sit behind a bot check (Anubis). Read threads on
  `lkml.rescloud.iu.edu` or `lists.infradead.org/pipermail`, keep the lore Message-ID, and read torvalds `master` on
  the GitHub mirror.
- The owner's web clippings in `~/code/obsidian/the build host/Clippings/` may already hold the thread (the X1E CPUFreq series
  was there).

Queued:

- `fcc-p212g.md`: FCC filings for regulatory model P212G (internal photos, chip markings, SSD placement)
