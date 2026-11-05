# SCMI over the CPUCP mailbox, and why PSCI cpuidle is off

On mica the three CPU clusters take their performance levels from a firmware core, and mainline talks to it with the
System Control and Management Interface (SCMI) over a mailbox. That path stalled on most boots, and the board device
tree now turns Power State Coordination Interface (PSCI) cpuidle off because of it. The evidence is in
[the SCMI research note](docs/research/scmi-cpucp-timeouts.md) and [the recon note](docs/recon/scmi-2026-11-03.md),
which number boot attempts per day as `2026-11-03-N`, shortened to `-N` below; the decisions are
[ADR 0008](docs/adr/0008-no-psci-domain-idle-states.md) and [ADR 0009](docs/adr/0009-no-psci-cpuidle.md).

## What SCMI does on this SoC

The mailbox is the CPUSS Control Processor (CPUCP) mailbox controller, `qcom,x1e80100-cpucp-mbox`, a doorbell between
the application processor and the CPUCP (the pinned kernel's binding, `qcom,cpucp-mbox.yaml`). The SCMI node uses
mailbox channels 0 and 2 with shared memory in SRAM, and each CPU takes its `perf` domain from `scmi_dvfs`; the stock
tree drives the same block the same way (recon note, "Why"). Up to attempt -7 the mailbox driver was a
module and the initramfs loads none, so `firmware:scmi` deferred forever. With `QCOM_CPUCP_MBOX=y` (attempt -8), SCMI
bound at 0.358 s, read `Firmware version 0x20000`, and `scmi-cpufreq` came up on all three clusters, 710.4 MHz to
3417.6 MHz under `schedutil` (recon note, "Result: pass"). [Status](docs/status.md) lists it as works.

## What failed

The next boot, attempt -9, had the same SCMI configuration and failed. From 0.437 s the log shows ten `timed out in
resp` lines about 36 ms apart (the 30 ms default timeout rounded up to jiffies at 250 Hz), then replies for requests
the kernel had already dropped: `Message for 7 type 0 is not expected!`. The version query was among the timeouts, so
the base protocol read `Firmware version 0x0`, and `scmi-cpufreq` probed with `-110` and never retried (research note,
section 1). The note reads this as a slow CPUCP, not lost interrupts, since other messages in the same window succeeded
(inference). Every upstream x1e80100 SCMI and CPUCP fix was already in the pinned kernel (research note, "Summary",
section 2).

A version of `0x0` carries a hazard. The quirk that forces the fast channel for `PERF_LEVEL_GET` is declared for
Qualcomm firmware from `0x20000` up; with the version unread it stays off, and the driver falls back to the regular
message that Sibi Sankar (Qualcomm) said crashes this firmware when idle states are enabled (research note, "Summary"
item 5 and section 4, [the review thread](https://lkml.rescloud.iu.edu/2412.0/06550.html)).

## Cold boot versus warm reset

The embedded controller's console separates cold starts (`G3->S5`) from warm resets out of running stock Android. On
2026-11-03 SCMI worked in both cold boots and failed in every warm reset; the same image failed warm (-11) and worked
cold (-12). The recon note's inference is that the stock kernel leaves the CPUCP in a state that survives a warm
reset, so stock is powered off before every attempt (recon note, "Update: cold boot vs warm reset", 5:25 PM ET). By
5:59 PM ET three cold starts had given one `-110`, one run of timeouts and one pass, so a cold start is no guarantee
either (recon note, "Update: cold starts fail too").

## Measuring the replies

The research note recommended measuring first, then sizing `arm,max-rx-timeout-ms` from the measured latency ("Ranked
recommendation"). On attempt -22 the trace showed the base protocol's discovery messages taking 23 to 36 ms
each; the implementation-version message took 36.0 ms, which the 30 ms default misses, leaving the version `0x0`.
Other replies took 155 to 222 ms, four requests timed out at 250 ms (one message twice), and the boot still came up
(recon note, "Update: reply latency per message").

| Window | Boots | Outcome | Source (recon note) |
|---|---|---|---|
| 30 ms (default) | 7 cold starts | 2 good | "Update: 1000 ms window" |
| 250 ms | -20, -21, -22 | -20 failed (7 timeouts of 78, version `0x0`); -21 clean, 4.0 ms peak; -22 up with 4 timeouts | "Update: the 250 ms window and the trace", "Update: reply latency" |
| 1000 ms | -23, -24, -25 | all pass; -23 and -24 with single replies at 0.6 to 1 s, -25 within 3.6 ms | "Update: 1000 ms window" |

When the CPUCP answers, it answers in milliseconds; on a bad boot single messages wait up to a second or never come,
and the window only absorbs that (recon note, "Update: 1000 ms window"). The board DTS carries
`arm,max-rx-timeout-ms = <1000>` on `/firmware/scmi`. No stock node has it, so [the DT README](dts/README.md) lists it
as unverified.

## The stall

With `cpuidle.off=1` every reply came within 0.1 ms on 3 of 3 cold starts (recon
note, "Update: cpuidle.off=1 A/B"). With `arm,no-completion-irq` (polling) and idle states on, the CPUCP freed the
shared-memory channel within 0.1 ms of every request, 3 of 3: the CPUCP is not slow, the completion interrupt is. In
interrupt mode every boot counted one mailbox interrupt per reply, all on CPU 0, stalled boots included: the
interrupts arrive, late (recon note, "Update: arm,no-completion-irq A/B").

The wake trace on -32 shows what CPU 0 did during one 534 ms stall: it entered cpuidle `state1` (the PSCI retention
state `cluster_c4`) and left it 26694 times, about every 20 µs, while taking only three interrupts. The stall ended
when the `arch_timer`, a Private Peripheral Interrupt (PPI), ran; 6 µs later the mailbox interrupt was taken (recon
note, "Update: the wake trace"). The idle counters on -33 showed PSCI refusing the system-level composite state about
598000 times in 95 s ("Update: idle counters"). Removing every domain idle state gave 3 of 3
clean boots ("Update: no PSCI domain idle states"), but two later boots on that tree stalled with zero refusals and
CPU 0's loop at 130000 to 156000 entries ("Update: ADR 0008 is not enough"). A diagnostic kernel patch then routed the
mailbox's Shared Peripheral Interrupt (SPI) to CPU 1: the loop moved with it (CPU 1 at 134862 entries, CPU 0 at 6131)
and the reply stalled for 872 ms ("Update: the stall follows the interrupt's CPU"). The reading, marked inference in
every source, is that a core in PSCI retention is woken by a pending SPI but does not take it until a PPI runs.

## The A/B tests

The counts are the recon note's own tally lines (`scripts/attempt.sh tally` reads machine-recorded boot health; a
"clean" boot has no timeout and every reply under 100 ms: [status](docs/status.md), "What clean means").

| Configuration | Stalled boots | Source |
|---|---|---|
| PSCI domain idle states present, interrupt mode (-23 to -27, -30 to -33) | 7 of 10 known, -31 unknown | recon note, "Update: the counts from attempt.sh tally" |
| ADR 0008's DT, no domain idle states (-34, -35, 2026-11-04-1 to -3) | 3 of 7 | same |
| Polling, `arm,no-completion-irq` (-29) | 0 of 3 | same |
| No PSCI cpuidle (-28, 2026-11-04-4) | 0 of 4 | same |
| No PSCI cpuidle at ten boots (adds 2026-11-04-5 to -10) | 0 of 10 | "Update: the tally at ten boots without PSCI cpuidle" |

At ten boots, no PSCI cpuidle against domain states present is a one-sided Fisher p of 0.0015; against ADR 0008's DT
it is 0.051 (same section). ADR 0009 later records 0 of 17 ("Update 2026-11-04 (11:24 AM ET)"), the count status
carries today.

## Two decisions

ADR 0008 (accepted 2026-11-03) deleted the cluster and system `domain-idle-states` from the board DTS and kept per-CPU
retention. The 2026-11-04 boots above showed the stall did not need the composite states, and the ADR was superseded
the same day (ADR 0008, "Status" and "Update 2026-11-04").

ADR 0009 (accepted 2026-11-04) deletes `cluster_c4` from `cpu_pd0` to `cpu_pd11` instead. With no idle state on any
CPU, `cpuidle-psci` does not load and every core idles in WFI, as under `cpuidle.off=1`; the cluster and system
states return to stock, since nothing requests them; the 1000 ms window stays (ADR 0009, "Decision"). Attempt
2026-11-04-4 confirmed it: no cpuidle driver, 78 replies within 0.1 ms, cpufreq on all three clusters (ADR 0009,
"Update 2026-11-04 (12:57 AM ET)"). Both ADRs are deliberate deviations from the stock tree under
[ADR 0004](docs/adr/0004-device-tree-from-9345.md), recorded in the DT README.

What it costs: no core enters PSCI retention and no cluster or the SoC powers down when idle, so idle power is higher
by an amount that has not been measured (ADR 0009, "Consequences"). Status lists CPU idle as partial for that reason;
the measurement is parked until a battery-only session, because the debug cable powers the bench (status, "CPU idle"
and "Idle power"). An s2idle round trip completes on this DT, in WFI, but which low-power state the SoC reaches is
unmeasured (ADR 0009, "Update 2026-11-04 (5:01 AM ET)").

## What is still open

- Why a core in retention does not take a pending SPI until a PPI runs: the GIC's wake path or the PSCI firmware
  (ADR 0009, "Consequences").
- Whether the CPUCP also answers within 0.1 ms when every core sleeps: untested (recon note, "Update: what -29 shows
  and does not").
- A warm reset from stock now works, 1 of 1, but with the window and ADR 0009 both in place, so which change fixed
  it is not separated (status, "SCMI after a warm reset from stock", inference).
- The 1000 ms window stays unverified (recon note, "Update: 1000 ms window").

A report on the mechanism is drafted. It is held, not sent: under
[ADR 0010](docs/adr/0010-milestones-status-upstream-hold.md) nothing goes to a mailing list before milestone M5, and
the owner reviews and sends it then (ADR 0009, "Update 2026-11-04 (10:07 AM ET)").
