# 9. No PSCI cpuidle on mica: the per-CPU domains lose `cluster_c4`

## Status

Accepted 2026-11-04 (owner, grilling round 4: "yes" to all four). Supersedes
[ADR 0008](0008-no-psci-domain-idle-states.md). A deliberate deviation from the stock tree
([ADR 0004](0004-device-tree-from-9345.md)).

## Context

The evidence is in [scmi-2026-11-03.md](../recon/scmi-2026-11-03.md), attempts -27 to 2026-11-04-3.
- **The symptom:** SCMI replies from the CPUCP stalled for 0.5 to 1 s, with an occasional timeout, on most cold boots.
  The 1000 ms window kept every boot working.
- **No stalls:** with plain WFI (`cpuidle.off=1`, -28) and with polling (`arm,no-completion-irq`, -29), 0 of 3 each.
  Polled replies take 0.1 ms, so the CPUCP answers fast.
- **During a stall** (-32), the core that takes the reply's SPI leaves the PSCI `ret` state (`cluster_c4`,
  `arm,psci-suspend-param` `0x4`) about every 20 µs. It takes IPIs but not the SPI, until a timer PPI runs.
- **The stall follows the interrupt's CPU** (2026-11-04-3, `kernel/patches/0009` routing SPI 28 to CPU 1): CPU 1
  looped (134862 `state1` entries) and the reply stalled for 872 ms, while CPU 0 stayed normal.
- **The domain states are not the cause.** Removing the cluster and system states (ADR 0008) still left 2 of 6 cold
  boots stalling. The PSCI refusals of `ss3` (-33) ran alongside the stall.
- **Other SPIs stalled too:** GENI I2C timeouts on -30, and a loop with no SCMI pending on -32 (inference).
- **Mainline gives no per-CPU way out.** `irqaffinity=` always keeps the boot CPU (`kernel/irq/irqdesc.c:36`). A CPU
  without idle states makes cpuidle-psci fail for every CPU (`cpuidle-psci.c:399-401`, `:437-447` at `a804c57`).

## Decision

- **`x1e80100-google-mica.dts` deletes `domain-idle-states`** (`cluster_c4`) from `cpu_pd0` to `cpu_pd11`.
  `cpuidle-psci` then does not load, and every core idles in WFI, as with `cpuidle.off=1`.
- **The cluster and system domain states stay as stock.** Without cpuidle-psci nothing requests them, so ADR 0008's
  deletions are reverted.
- **The 1000 ms SCMI window stays** as a safety net and is still marked unverified.
- **`kernel/patches/0009`** (the IRQ-to-CPU-1 diagnostic) is deleted. The idle-counter and wake-trace tooling stays.
- **The upstream report** is rewritten around this mechanism in
  scmi-cpucp-stall-report.md and is not sent. Sending is a separate owner
  decision after the suspend test.

## Consequences

- No core enters PSCI retention, and no cluster or the SoC powers down when idle. Idle power is higher; how much has
  not been measured.
- `s2idle` uses cpuidle states, so suspend will not reach PSCI low-power states with this DT (inference). The suspend
  test is the trigger to revisit, together with a firmware update or an upstream answer.
- Why a core in `ret` does not take a pending SPI is open: the GIC's wake path, or the PSCI firmware. That is the
  report's question.

## Update 2026-11-04 (12:57 AM ET): confirmed on the board DTS

Attempt `2026-11-04-4` booted this DT (kernel `#21`). There was no cpuidle driver, SCMI replied within 0.1 ms (78 of
78, 0 timeouts), and cpufreq came up on all three clusters. With -28, plain WFI is 4 of 4 cold boots without a stall.

## Update 2026-11-04 (2:31 AM ET): the tally

`scripts/attempt.sh tally` ([scmi-2026-11-03.md](../recon/scmi-2026-11-03.md), "the counts from attempt.sh tally"):
domain states present 7 of 10 stalled against no PSCI cpuidle 0 of 4 (p = 0.035); ADR 0008's DT 3 of 7 against 0 of 4
(p = 0.21, not significant alone). The decision stands on the mechanism plus the first comparison. More boots on this
DT will sharpen the count; `record` now adds each one to the table.

## Update 2026-11-04 (4:40 AM ET): the suspend test, and the tally at ten boots

The suspend test ran: six cold boots, `2026-11-04-5` to `-10`
([suspend-2026-11-04.md](../recon/suspend-2026-11-04.md)). s2idle entry and the RTC wake work. The resume resets the
SoC every time, in the PCIe controllers' noirq resume: first the PCIe GDSCs (fixed by local patch 0008, from an
upstream series), then the NVMe endpoint behind PCIe 6a (link kept) and PCIe 4's host re-init (link shut down). The failure comes before any idle
state matters, so the test neither confirms nor refutes this ADR's suspend cost (inference). The revisit stays open
until a resume completes.

Those boots also added to the count (`scripts/attempt.sh tally` with group 2 `'^2026-11-03-28$|^2026-11-04-([4-9]|10)$'`;
kernels #21 to #23 and the no-PCIe-6a diagnostic DT, none of which touches the SCMI probe). No PSCI cpuidle: 0 of 10
stalled. Against domain states present, 7 of 10: p = 0.0015. Against ADR 0008's DT, 3 of 7: p = 0.051.

## Update 2026-11-04 (5:01 AM ET): a complete suspend round trip, and the count against ADR 0008

With local patches 0008 and 0009 (the PCIe GDSCs and the PCIe PHY GDSCs to retention), attempt `2026-11-04-11`
completed an s2idle round trip on this DT ([suspend-2026-11-04.md](../recon/suspend-2026-11-04.md), newest update).
The CPUs had no cpuidle driver, so s2idle ran in WFI. Whether the SoC reached a low-power state, and at what power, is
not measured. The revisit trigger is met, and the suspend cost of this ADR is still the open question. Measuring it
needs a power reading that is not charge current.

Count: console boot #11 adds one more clean boot to -10. Group 2 is now `'^2026-11-03-28$|^2026-11-04-([4-9]|1[01])$'`:
0 of 12 stalled. That is p = 0.0007 against domain states present (7 of 10), and **p = 0.036 against ADR 0008's DT
(3 of 7)**, now under 0.05.

## Update 2026-11-04 (5:13 AM ET): suspend 3 of 3, the count at 14

Two more boots of -11's image completed the round trip too: 3 of 3
([suspend-2026-11-04.md](../recon/suspend-2026-11-04.md)). All were clean for SCMI. The same group 2 regex now gives
0 of 14 stalled: p = 0.0003 against domain states present, and p = 0.026 against ADR 0008's DT.

## Update 2026-11-04 (10:07 AM ET): when the report is sent

The "Decision" line that made sending scmi-cpucp-stall-report.md an owner
decision after the suspend test is superseded by [ADR 0010](0010-milestones-status-upstream-hold.md). The report waits
for milestone M5, like the binding and DTS. The owner reviews and sends it, and an agent never does.

This ADR's "patch 0009" is the deleted IRQ-to-CPU-1 diagnostic (`cee735d`). Today's `kernel/patches/0009` is a
different patch, the PCIe PHY GDSCs, added before numbers were retired ([ADR 0007](0007-local-kernel-patches.md)
update).

## Update 2026-11-04 (11:24 AM ET): the first base image, and the count at 17

Attempt `2026-11-04-12` is the first base image on this DT with patches 0008 and 0009: kernel #26, no command-line or
DT extras. It had 3 cold boots, all clean for SCMI. `scripts/attempt.sh tally` with group 2
`'^2026-11-03-28$|^2026-11-04-([4-9]|1[0-2])$'` gives `boots=17 known=17 stalled=0 clean=17`: no PSCI cpuidle has
0 of 17 stalled.
