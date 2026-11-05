# 10. Milestones M0 to M7, a feature status table, and the upstream hold ends at M5

## Status

Accepted 2026-11-04 (owner: "all a" to the open questions 1, 7 and 9 of
[milestones-versioning.md](../research/milestones-versioning.md), section 5). Supersedes the line in
[ADR 0009](0009-no-psci-cpuidle.md) "Decision" that made sending the stall report an owner decision after the suspend
test.

## Context

- The phases and gates (README "Phases and gates") mark four big steps. Phase 3, from first boot to a daily-drivable
  install, is a long stretch with no checkpoint in between. Progress was tracked as prose in README "Resume here".
- Comparable projects track progress per feature and per stage (research note, section 1):
  - Asahi's feature-support tables have a column saying where each feature lives (upstream release, downstream, WIP).
  - postmarketOS (now Nura) puts devices into categories with entry criteria.
  - The XPS 13 9345's first upstream DTS went in with the EC, speakers, mics and camera not working, and it listed what
    worked and what did not.
- The kernel's process documents favour posting early (`3.Early-stage.rst`, `5.Posting.rst` at the pin). A board DTS
  needs a documented compatible (bindings `submitting-patches.rst` item 7), must pass `dtbs_check` with no new warnings,
  and must pass `dt-check-style` in relaxed mode (`maintainer-soc.rst`) (research note, section 3).
- AI agents must not add `Signed-off-by` and must never send anything themselves (`coding-assistants.rst:34` at the
  pin). 207 of the repo's 210 commits had a Claude co-author trailer (`git log`, 2026-11-04).
- On 2026-11-04 the owner put upstream sends (the SCMI stall report, patch 0009) on hold "until the project progresses
  further".

## Decision

- **The milestone ladder.** Each rung fits inside the phases and gates:

  | M | Name | Phase / gate | Done when |
  |---|---|---|---|
  | M0 | Way back to stock | Phase 1, Gate 1 | recovery media reach the recovery screen and relock is tested ([ADR 0001](0001-recovery-gates-unlock.md)) |
  | M1 | First light | Phase 2, Gate 2 | our `Linux version` line on the AP console, the panel or the readback |
  | M2 | Board on the console | Phase 3 | every enabled DT node binds; the M2 rows of [`docs/status.md`](../status.md) read works; every other row is works, or partial or parked with a note; one base image has 3 clean cold boots by `scripts/attempt.sh tally` |
  | M3 | Userspace from USB | Phase 3 | a rootfs from USB with Mesa on the GPU and Wi-Fi in userspace; the audio state is known; the first release tag ([ADR 0011](0011-versions-and-releases.md)) |
  | M4 | Daily-drivable | Phase 3, Gate 3 | installed on the spare SSD ([ADR 0002](0002-experiment-on-spare-ssd.md)), with dual-boot or a documented return to stock |
  | M5 | Upstream-ready | Phase 4 entry | the `google,mica` binding and the DTS, rebased on the qcom tree, pass `dt_binding_check`, `dtbs_check` (no new warnings), relaxed `dt-check-style` and `checkpatch.pl`; a Working / Not working list is written; every local patch has its status line; the owner has reviewed and signed off every patch |
  | M6 | Upstream | Phase 4, Gate 4 | the binding and DTS are applied to the qcom tree, then reach a mainline release |
  | M7 | In a distribution (optional) | after Phase 4 | a Nura `testing` device package, or an Ubuntu Concept entry |

  The M2 rows are: USB host, Type-C, PCIe enumeration, Wi-Fi, eDP and backlight, GPU probe, EC keyboard, touchpad,
  TPM, SCMI cpufreq and an s2idle round trip. A base image is one with no debug command-line or DT extras: its
  `scripts/attempt.sh stick` first line reads `base image`.
- **[`docs/status.md`](../status.md) is the feature matrix.** It has one row per feature and four state words: works,
  partial, broken, untested. Untested is the default. Each row says where the feature works (mainline at the pin, a
  local patch, the board DTS, a config fragment), what upstream has or what gbook would have to send, and the recon note
  behind it. README "Resume here" points to it. Its prose stays as the owner's dated record.
- **The upstream hold ends at M5.** Nothing goes to a list before then. At M5 the binding and DTS go out first as a
  `[PATCH RFC]` series, following the kernel's own versioning ([ADR 0011](0011-versions-and-releases.md)). The stall
  report and patch 0009 wait for the same bar. The owner reviews, signs and sends every patch. An agent never adds
  `Signed-off-by` and never sends.
- **The research note's other rider is the owner's call.** It suggests a recon post in `#aarch64-laptops` before M5
  (Phase 1 list in the project log). That post is the owner's to make, and an agent does not post.

## Consequences

- Progress has a name between the gates: "M2 nearly done" says more than "Phase 3".
- `docs/status.md` has to be kept current. A recon note that changes a feature's state also changes its row.
- M5 can run in parallel with M3 and M4, because it is about the binding and DTS, not userspace.
- What blocks M5 today (inference, research note section 3): the unverified `arm,max-rx-timeout-ms`, ADR 0009's
  deleted idle states, the merge-window pin, and the panel entry that lacks the full model name.

## Update 2026-11-04 (11:37 AM ET): parking untested rows

Owner, park round ("yes" to all recommendations). A parked row in `docs/status.md` keeps its state (untested,
partial or broken), and its note says "parked until <milestone or condition>". M2's third criterion counts a parked row
as settled. The first round parked 16 rows:
- NVMe I/O until the spare SSD (M4);
- the left port's USB 3 and DP until a session without the SuzyQ;
- idle and suspend power until a battery-only session;
- audio, camera, fingerprint, the rootfs and Mesa until M3;
- the lid switch, ambient-light sensor and Glowbar until a stock-tree or EC lead;
- the crypto engine until upstream drops `BROKEN`.

Three rows stay open for M2: wake from s2idle by a key or the power button, deep suspend, and Bluetooth.

## Update 2026-11-04 (12:38 PM ET): M2 reached

All four criteria of M2 are met ([`docs/status.md`](../status.md), "Milestone M2"):
- every enabled DT node binds, by the `unbound=` proxy;
- the twelve M2 rows work; the backlight was set and read back in 3 of 3 base-image boots;
- every other row works, is partial, or is parked: Bluetooth works (2026-11-04-14), keyboard wake from s2idle is
  partial (-15), deep suspend failed and is parked (-16), and 16 rows were parked in the park round;
- the base image 2026-11-04-12 has 3 clean cold boots (`tally`).

The next milestone is M3, userspace from USB. Its first base image that passes the release bar gets the first tag
([ADR 0011](0011-versions-and-releases.md)).

## Update 2026-11-04 (7:11 PM ET): M3's technical criteria have evidence; the release is pending

Three ROOT boots on 2026-11-04 (attempts -18 to -20; [rootfs-2026-11-04.md](../recon/rootfs-2026-11-04.md)): a rootfs
from USB with Mesa on the GPU (eglinfo, kmscube, cage and vkcube on the Adreno X1-85), Wi-Fi in userspace (the
supplicant and networkd carried the netlog), and the audio state known (`aplay -l`: no sound card; the attempt is
ticket 10). The status rows "Rootfs from USB" and "Mesa (freedreno)" read `works`. M3 closes with the first release tag
([ADR 0011](0011-versions-and-releases.md)): a snapshot-pinned rootfs build, 3 clean cold boots of one base image, and
the owner's tag drafted by `scripts/release-draft.sh`.

## Update 2026-11-04 (8:39 PM EST): M3 reached, first release `v2026.11.04`

The release bar was met the same evening: the rootfs rebuilt from snapshot `20261104T000000Z` (321 packages,
`4b0e2e027c0b2d74…`), written to ROOT and read back equal (`attempt.sh root-cmd`, `root-verify`), then three clean cold
boots of base image `9673d6d782ef4cdb` (attempts -21 to -23, `tally` clean=3 stalled=0;
[rootfs-2026-11-04.md](../recon/rootfs-2026-11-04.md), "Release boots"). The owner tagged `v2026.11.04` from
`scripts/release-draft.sh`'s message and pushed it to the private remote. M3 is passed. The upstream hold stays until M5; the next
milestone is M4, daily-drivable (Gate 3).
