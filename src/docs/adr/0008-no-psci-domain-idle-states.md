# 8. The board DTS removes the PSCI domain idle states (cluster cl4/cl5, system ss3)

## Status

**Superseded 2026-11-04 by [ADR 0009](0009-no-psci-cpuidle.md)** (owner round 4): the stall does not need the
domain states; the board DTS now drops the per-CPU `cluster_c4` instead and keeps the domain states as stock.

Accepted 2026-11-03 (owner, grilling round 2: "yes" to all four). A deliberate deviation from the stock tree
([ADR 0004](0004-device-tree-from-9345.md)).

## Context

- On mica the CPUCP's SCMI replies stalled for 0.5 to 1 s on most cold boots, with a timeout now and then. That
  needed the local `arm,max-rx-timeout-ms = <1000>` to come up at all
  ([scmi-2026-11-03.md](../recon/scmi-2026-11-03.md), attempts -20 to -26).
- A/B boots, all cold, interrupt mode unless noted:
  - **Without `cluster_cl5` (-27) or without `domain_ss3` (-30):** both still stalled.
  - **No stalls:** `cpuidle.off=1` (-28), polling with `arm,no-completion-irq` (-29), and no domain idle states at all
    (-34). Each was 3 of 3, with replies within 0.1 to 4 ms.
  - **With the domain states present:** 8 of 11 boots stalled.
- **The wake trace (-32):** during a stall, CPU 0, which takes the mailbox interrupt, left the PSCI `ret` state every
  ~20 µs without taking any interrupt.
- **The counters (-33):** PSCI in OS-initiated mode refused the composite `ss3` request about 598000 times in 95 s,
  from the last CPU of clusters 1 and 2, and genpd retried each time.
- **The stock tree** has the same four states and topology (`entry00-base.dts`: `cluster_pd0`-`2` with `cl4` and
  `cl5`, `system_pd` with `system_ss3`). Stock runs Qualcomm's own cpuidle and SCMI stacks, so its behaviour does not
  carry over (inference).

## Decision

- **`x1e80100-google-mica.dts` deletes `domain-idle-states`** from `cluster_pd0`, `cluster_pd1`, `cluster_pd2` and
  `system_pd`. The per-CPU domains keep `cluster_c4`, so CPUs still enter PSCI retention.
- **The 1000 ms SCMI window stays** as a safety net. It costs nothing on a fast boot and is still marked unverified.
- **Polling stays a diagnostic.** `arm,no-completion-irq` is not in the board DTS: the binding describes hardware
  without a completion interrupt, and mica has one.
- **Upstream waits.** A report draft lives in
  scmi-cpucp-stall-report.md, and sending it is a separate owner decision
  after the suspend test.

## Consequences

- The clusters and the SoC never power down when idle, so idle power is higher. How much has not been measured.
- Suspend is untested either way. It is the trigger to revisit this ADR, together with a firmware update or an
  upstream fix. The finer cut, keeping `cl4` and dropping `cl5` and `ss3`, was not tested.
- Why the firmware refuses the composite states, and how that delays the interrupt to CPU 0, is still open.
- `dts/README.md` lists the change under "Changes" as a deviation, citing this ADR.

## Update 2026-11-04 (12:26 AM ET): not a complete fix

Attempts `2026-11-04-1` and `-2` stalled on this board DTS (max replies 1019.2 ms with 2 timeouts, then 652.0 ms):
2 of 6 cold boots without domain idle states, against 8 of 11 with them. Both stalled boots show CPU 0's `state1`
loop (130000-156000 entries by the early read, against 4700-19000 on clean boots) with 0 PSCI refusals, so the
stall does not need the composite states ([scmi-2026-11-03.md](../recon/scmi-2026-11-03.md), "ADR 0008 is not
enough"). The decision is open again: keep, revert or replace this change. The 1000 ms window keeps every boot
working either way.
