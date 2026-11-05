# SCMI over the CPUCP mailbox: intermittent timeouts at boot

Researched 2026-11-03 from the kernel source at the pin (`a804c5742bff`, `Makefile` says 7.3.0; it sits between
`v7.3` and `v7.4-rc1`), torvalds `master` via the GitHub mirror (head `05441d697f7f`, 2026-11-03), the upstream
review threads, and the attempt -8/-9 logs. lore.kernel.org, patchwork and git.kernel.org sit behind a bot check
(Anubis), so threads were read on the LKML mirror `lkml.rescloud.iu.edu` and on `lists.infradead.org`; lore
Message-IDs are given where the mail quotes them. Mirror dates are US Eastern. Read 2026-11-03. The device was not
touched.

## Summary

1. **Attempt -9 shows a slow CPUCP, not lost interrupts.** Replies came later than the 30 ms timeout between 0.37 s
   and 0.81 s (how much later is not in the log), while some messages in the same window succeeded, and the TX channel was still held when the next request
   was due (section 1). *Inference* from the log and `shmem.c:88-119`.
2. **Every upstream x1e80100 SCMI/CPUCP fix is already at the pin.** The one later mailbox fix (`readq()`, v7.4-rc1)
   does not touch the SCMI reply path. No upstream patch to backport was found (section 2).
3. **No upstream x1e board overrides the `scmi` node.** Nor does the stock mica tree (section 3).
4. **Upstream never reported this boot-time stall.** Their x1e timeouts were on resume (IRQ disabled, fixed) and on
   PERF_LEVEL_GET by regular message (firmware crash, fixed by a quirk). Both fixes are at the pin (section 4). No
   primary report of an intermittent boot-time `-110` on X1 laptops was found (section 5).
5. **Hazard:** a bad boot reads the firmware version as `0x0`. The FastChannel quirk then stays off, and
   PERF_LEVEL_GET falls back to the regular message that Qualcomm says crashes this firmware (section 4).

## Ranked recommendation

1. **Measure first.** Boot the same image several more times to get a failure rate. Add
   `CONFIG_ARM_SCMI_DEBUG_COUNTERS=y` and the `scmi` trace events so each failure shows which message and how late
   the reply was.
2. **Then set `arm,max-rx-timeout-ms` on mica's `scmi` node,** sized from the measured latency (a bounded value such
   as 100-250 ms, not i.MX's 5000). The property is in the binding and driver at the pin. A boot passes only if it
   prints the new `SCMI max-rx-timeout: <N>ms` (`driver.c:3205-3208`), `Firmware version 0x20000` and `Enabling SCMI
   Quirk [quirk_perf_level_get_fc_force]`.
3. **Guard against the hazard:** treat `Firmware version 0x0` or a missing FC quirk line as a failed boot, and never
   rebind `scmi-cpufreq` in such a boot. A local `kernel/patches/` file that matches the quirk without the version
   range is optional (section 6).
4. **One-off diagnostics,** not configs to keep: `arm,no-completion-irq` (polling) and `cpuidle.off=1` A/B boots.

## 1. What -8 and -9 show

Source: `dumps/firstboot/2026-11-03-netlog.txt` (gitignored), the `scmi-dmesg` capture of each boot. Same config;
-9 adds only `kernel/patches/0001` (panel-edp). Kernel `CONFIG_HZ=250` (`build-a804c57/.config:483`).

| | -8 (good) | -9 (bad) |
|---|---|---|
| `Using scmi_mailbox_transport` | 0.358 s | 0.367 s |
| First timeout | none | 0.437 s, then every ~36 ms (30 ms timeout rounded up to 8 jiffies at 250 Hz, plus one) |
| Base protocol line | 0.361 s, `Firmware version 0x20000` | 0.541 s, `Firmware version 0x0`, after 3 timeouts |
| Quirks enabled | `perf_level_get_fc_force`, `clock_rates_triplet_out_of_spec` | `clock_rates_triplet_out_of_spec` only |
| Late replies | none | `Message for 7` at 0.579 s, `9` at 0.650 s, `32` at 0.809 s |
| Perf protocol | normal | `Failed to query supported version for protocol 0x13` (0.613 s) |
| `scmi-cpufreq` | 3 policies | `-110` at 0.649 s, never retried |
| `Initialized 3 performance domains` | 0.376 s | 0.806 s |

What the log and the source say:
- **The boot waited on SCMI.** In -9 the only other kernel line between 0.369 s and 0.805 s is `Freeing initrd
  memory`, and `simpledrm` comes at 0.807 s (0.377 s in -8). All SCMI work took 18 ms in -8.
- **The firmware held the channel.** Two timeouts are 68 ms apart (0.473 s to 0.541 s), not 36 ms.
  `shmem_tx_prepare()` busy-waits up to 2 × the timeout for the platform to set `CHANNEL_FREE` before it writes a new
  request (`drivers/firmware/arm_scmi/shmem.c:94-119`). It did not give up (no `Timeout waiting for a free TX
  channel !`). *Inference:* CPUCP was still busy with the request that had timed out, so the next request waited
  about 32 ms. The same gap fits one slow reply (~32 ms, under the timeout) between two timeouts; both readings mean
  a slow firmware. The first gap (0.369 s to 0.437 s) is the same shape.
- **The interrupt path works.** The late replies are reported through the IRQ path (`transports/mailbox.c:54-78` to
  `driver.c:1012-1023`). Messages in the same window also succeeded: the OPP lines at 0.656-0.660 s need several
  PERF replies. A lost or disabled IRQ would fail every message.
- **"Message for N type 0 is not expected!"** means a reply came for a token the kernel had already given up on
  (`scmi_xfer_command_acquire()`, `driver.c:1012-1023`; type 0 = command reply). The source describes this case: "a
  spurious IRQ from a previous timed-out reply which arrived late" (`transports/mailbox.c:58-66`).
- **Why it can happen this early** (*inference*): on mica, SCMI is built in and binds at 0.36 s, right after
  depthcharge, which loaded CPUCP through coreboot ([el2-handoff.md](el2-handoff.md)). On the UEFI devkit upstream
  tested, SCMI bound at 7.9 s (Marc Zyngier's dmesg, section 4), so upstream may never run in this early
  window.

## 2. Upstream fixes and whether the pin has them

Presence was read in the pinned source; the landing release is the first tag that contains the commit (GitHub
`compare` API against torvalds tags).

| Commit | Title | Release | At `a804c57` |
|---|---|---|---|
| [`d2fab3fc27cb`](https://github.com/torvalds/linux/commit/d2fab3fc27cb) | mailbox: qcom-cpucp: Mark the irq with IRQF_NO_SUSPEND flag (Sibi Sankar, 2024-10-30; fixes the x1e resume timeout) | v6.12 | yes, `drivers/mailbox/qcom-cpucp-mbox.c:176` |
| [`da1642bc97c4`](https://github.com/torvalds/linux/commit/da1642bc97c4) | firmware: arm_scmi: Queue in scmi layer for mailbox implementation (timeouts no longer start while queued) | v6.12 | yes, `transports/mailbox.c:288-305` |
| [`a0a18e91eb3a`](https://github.com/torvalds/linux/commit/a0a18e91eb3a) | firmware: arm_scmi: Reject clear channel request on A2P | v6.12 | yes, `driver.c:1067-1077` |
| [`1780e411ef94`](https://github.com/torvalds/linux/commit/1780e411ef94) + [`54962707f8b8`](https://github.com/torvalds/linux/commit/54962707f8b8) | Use max-rx-timeout-ms from devicetree; Use vendor string in max-rx-timeout-ms | v6.12 | yes, `driver.c:3187-3190`; binding `Documentation/devicetree/bindings/firmware/arm,scmi.yaml:127-132` |
| [`5d8a76622658`](https://github.com/torvalds/linux/commit/5d8a76622658) + [`e2261bb81e0d`](https://github.com/torvalds/linux/commit/e2261bb81e0d) | Skip opp duplicates; Report duplicate opps as firmware bugs (the `[Firmware Bug] … opps_by_lvl` lines) | v6.12 | yes (`perf.c`, the -8 log lines) |
| [`c23c03bf1faa`](https://github.com/torvalds/linux/commit/c23c03bf1faa) | Fix timeout checks on polling path | v6.15 | yes (polling path only) |
| [`487c407d57d6`](https://github.com/torvalds/linux/commit/487c407d57d6), [`94a263f981a3`](https://github.com/torvalds/linux/commit/94a263f981a3), [`397f802d06c4`](https://github.com/torvalds/linux/commit/397f802d06c4) | quirk framework; Ensure that the message-id supports fastchannel; quirk: Force perf level get fastchannel (Johan Hovold) | v6.16 | yes, `quirks.c:173-174`, `driver.c:1924-1951` |
| [`06e3c7ec8045`](https://github.com/torvalds/linux/commit/06e3c7ec8045) + [`892c83aa39cb`](https://github.com/torvalds/linux/commit/892c83aa39cb) | arm64: dts: qcom: x1e80100: Add cpucp mailbox and sram nodes; Enable cpufreq | v6.16 | yes, `hamoa.dtsi:338-351`, `:8568-8573`, `:8758-8776` |
| [`0fac05fdd9af`](https://github.com/torvalds/linux/commit/0fac05fdd9af) | Rework protocol version negotiation logic (source of `Trying version 0x40000`) | v7.0 | yes, `driver.c:2169-2211` |
| [`d8283ac2c8fb`](https://github.com/torvalds/linux/commit/d8283ac2c8fb) | Implement arm,no-completion-irq property | v7.1 | yes, `driver.c:3202-3203`, binding `:149-154` |
| [`3690aaa6d18f`](https://github.com/torvalds/linux/commit/3690aaa6d18f) + [`fc4f2f995302`](https://github.com/torvalds/linux/commit/fc4f2f995302) | qcom-cpucp: fix PREEMPT_RT self-deadlock in IRQ handler; handle NULL data in send_data callback | v7.3 | yes, `qcom-cpucp-mbox.c:69-84`, `:120-126` |
| [`74f1cf02d9fe`](https://github.com/torvalds/linux/commit/74f1cf02d9fe) | mailbox: qcom-cpucp: read mbox hardware register using readq() | v7.4-rc1 | **no**: `qcom-cpucp-mbox.c:64` still reads 32 bits at `+0x4` |

Notes:
- **`74f1cf02d9fe` does not affect SCMI.** It changes only the value handed to the client. The SCMI mailbox client
  ignores that value: its `rx_callback()` reads the header from shared memory (`transports/mailbox.c:54-78`).
- **No newer change in master.** The other `arm_scmi` commits between the pin and master add ACPI support and fix raw
  mode (e.g. `f35ee1a26795`, `4f5f291a5704`, `0543fc1443de`). None touches timeouts or the mailbox path. linux-next
  could not be read (git.kernel.org bot check), so changes queued for 7.5 are unknown.
- **The default timeout is 30 ms** for the mailbox transport (`transports/mailbox.c:383`, "We may increase this if
  required"), with no Qualcomm-specific value anywhere.

## 3. Device trees: does anyone set something different?

- **The upstream SoC node** is `hamoa.dtsi:338-351`: `mboxes = <&cpucp_mbox 0>, <&cpucp_mbox 2>`, shmem
  `cpu_scp_lpri0/1` in `sram@18b4e000`, only `protocol@13`. The node has **no label**.
- **No x1e/x1p board file and no `x1-el2.dtso` mentions `scmi` or `cpucp`** (`rg` over
  `arch/arm64/boot/dts/qcom/x1*` and `purwa*`).
- **The other Qualcomm SCMI nodes** at the pin (`sm8750.dtsi:225-238`, `glymur.dtsi:409-422`,
  `kaanapali.dtsi:230-243`) set no timeout, no `atomic-threshold-us` and no `arm,no-completion-irq`.
- **The only users of the properties in arm64** are the i.MX SoCs with `arm,max-rx-timeout-ms = <5000>`
  (`freescale/imx95.dtsi:346`, `imx94.dtsi:84`, `imx952.dtsi:216`) and one Renesas board with
  `arm,no-completion-irq` (`renesas/r8a78000-ironhide.dts:31`).
- **Stock mica** (`dumps/recovery-16471258/dtbo/entry00-base.dts:384-403`) uses the same mailbox channels (`<cpucp 0
  cpucp 2>`) and adds `protocol@80`. It has no timeout property. The mailbox is `qcom,cpucp-v2`, IRQ SPI 28
  level-high (`:10535-10540`), the same as `hamoa.dtsi:8571`.
- **Consequence for a DT override:** mica's DTS includes `hamoa.dtsi`
  (`dts/x1e80100-google-mica.dts:22`), so the override has to use a path reference, `&{/firmware/scmi} { … };`. Per
  ADR 0004 it is not from the stock tree, so mark it "unverified" in `dts/README.md`.

## 4. What the maintainers said

The CPUFreq series review ("[PATCH V7 0/2] qcom: x1e80100: Enable CPUFreq", [lore](https://lore.kernel.org/all/20241030125512.2884761-1-quic_sibis@quicinc.com/)):

- **Johan Hovold, 2024-11-01:** grepping cpufreq sysfs on the CRD reset the machine after `arm-scmi arm-scmi.0.auto:
  timed out in resp(caller: do_xfer+0x164/0x564)`
  ([2411.0/00567](https://lkml.rescloud.iu.edu/2411.0/00567.html)).
- **Marc Zyngier, 2024-11-01:** "I'm seeing similar things indeed. Randomly grepping in cpufreq/policy* results in
  hard resets". His dmesg has `SCMI max-rx-timeout: 30ms` and the SCMI bind at 7.93 s
  ([00663](https://lkml.rescloud.iu.edu/2411.0/00663.html)).
- **Johan, 2024-11-05:** the ThinkPad T14s "hard resets when accessing the cpufreq sysfs attributes as well"
  ([05166](https://lkml.rescloud.iu.edu/2411.0/05166.html)).
- **Sibi Sankar (Qualcomm), 2024-12-05, root cause:** "The PERF_LEVEL_GET implementation in the SCP firmware side
  is the reason for the crash … the crash happens when idle states are enabled and a regular LEVEL_GET message is
  triggered from the kernel. This was fixed a while back but it will take a while to flow back to all the devices"
  ([2412.0/06550](https://lkml.rescloud.iu.edu/2412.0/06550.html)).
- **Marc, 2024-12-05:** "this fix will never reach some platforms … How do we distinguish between good and bad
  firmware versions?" ([06821](https://lkml.rescloud.iu.edu/2412.0/06821.html)).
- **Sibi, 2025-01-06:** "The perf protocol version won't have any changes so detecting it isn't possible", and "the
  X1E firmware supports fast channel level get but when queried it says it doesn't support it … The PERF_LEVEL_GET
  regular messaging which gets used as a fallback has a bug which causes the device to crash"
  ([2501.0/03550](https://lkml.rescloud.iu.edu/2501.0/03550.html)).
- **Johan, 2025-01-10, the mitigation:** "Why can't you add a quirk for x1e platforms that makes sure that the driver
  always uses fastchannel level get?" ([2501.1/03949](https://lkml.rescloud.iu.edu/2501.1/03949.html)).
- **The outcome:** that quirk is `397f802d06c4`
  ([lore](https://lore.kernel.org/all/20250430135146.5154-1-johan+linaro@kernel.org/)). Its message says
  the firmware "does not set the FastChannel supported attribute bit for PERF_LEVEL_GET but crashes when falling
  back to regular messaging", and that an upper version bound can be added "when we learn which version has a fix".
  Johan asked to merge the DT "With the SCMI perf quirk for the Qualcomm firmware merged for 6.16"
  ([2505.1/00578](https://lkml.rescloud.iu.edu/2505.1/00578.html)). Bjorn Andersson applied both DT patches on
  2025-05-17 ([2505.2/01472](https://lkml.rescloud.iu.edu/2505.2/01472.html)).

The earlier resume timeout ("Ensure that the message-id supports fastchannel", 2024-09):
- **Johan:** the patch "breaks resume from suspend on the x1e80100 crd … `arm-scmi firmware:scmi: timed out in
  resp(caller: do_xfer+0x164/0x568)`" ([958170](https://lists.infradead.org/pipermail/linux-arm-kernel/2024-September/958170.html),
  [lore](https://lore.kernel.org/lkml/ZtgFj1y5ggipgEOS@hovoldconsulting.com/)).
- **Konrad Dybcio:** "it looks like PERF_LEVEL_GET (msgid 8) requires the use of FC, but the firmware fails to inform
  us about it through BIT(0) in attrs" ([958413](https://lists.infradead.org/pipermail/linux-arm-kernel/2024-September/958413.html)).
- **Sudeep Holla** asked why the firmware would not implement PERF_LEVEL_GET on the normal channel ("I am very much
  interested to know the reason") ([958443](https://lists.infradead.org/pipermail/linux-arm-kernel/2024-September/958443.html)).
- **Sibi, 2024-10-06, root cause:** "the SCP was servicing the request but mailbox had the interrupt disabled during
  suspend which caused the timeout". The fix is `IRQF_NO_SUSPEND` (`d2fab3fc27cb`, at the pin)
  ([966573](https://lists.infradead.org/pipermail/linux-arm-kernel/2024-October/966573.html)).

**Late replies in general:** Cristian Marussi (Arm) explains the agent's per-message state machine and why a late
immediate reply is "discarded" ([2501.2/08228](https://lkml.rescloud.iu.edu/2501.2/08228.html), 2025-01-23). That
mail is about out-of-order *delayed* responses. -9's lines are type 0 (plain replies), which the source comments
above cover.

**What this means for -9** (*inference*):
- **The quirk failed for a known reason.** `perf_level_get_fc_force` is declared for vendor `"Qualcomm"` with
  implementation range `"0x20000-"` (`quirks.c:174`), and it is enabled only if `impl >= start_range`
  (`quirks.c:302-305`). The version query timed out, so the version read as `0x0` and the quirk stayed off.
- **The crash path was not taken, by luck.** `scmi-cpufreq` failed, so nothing sent PERF_LEVEL_GET. Had cpufreq
  bound in that boot, it would have used the regular-message fallback that Qualcomm says crashes the SCP. A partly
  failed boot is therefore riskier than a fully failed one.
- **No maintainer has spoken to this case.** None of the threads read here discusses SCMI timeouts at boot with an
  otherwise healthy firmware.

## 5. Reports from other X1 machines

- **Searched:** GitHub issues ("timed out in resp", "scmi" + "x1e") and web search for `scmi-cpufreq … -110` on
  Snapdragon X.
- **No primary report found** of an intermittent boot-time SCMI timeout or `scmi-cpufreq -110` on X1 laptops.
- **The known x1e reports** are the resume timeout and the sysfs hard reset (section 4), both fixed at the pin.
- **Unrelated:** `dwhinham/archiso-aarch64-sp11#36` (X1P64100 OPPs flagged turbo, a different firmware bug) and
  `Sky1-Linux/linux-sky1#25` (CIX SoC).

## 6. Options, ranked

| # | Option | Evidence | Cost and risk |
|---|---|---|---|
| 1 | **Measure:** more boots of one image. Add `CONFIG_ARM_SCMI_DEBUG_COUNTERS=y` (`Kconfig:58-70`; debugfs `scmi/0/transport/counters/`, e.g. `xfers_response_timeout`, `err_msg_unexpected`, `driver.c:3002-3046`) and tracing for the `scmi_xfer_begin`/`scmi_xfer_end`/`scmi_rx_done` events (`include/trace/events/scmi.h:37-145`). Read both in `/init`'s SCMI capture | One good and one bad boot give no rate. The counters and trace show which protocol/message waits and for how long. `CONFIG_FTRACE` is unset and the counters are off (`build-a804c57/.config:2028`) | Config fragment only. Tracing makes the image bigger |
| 2 | **`arm,max-rx-timeout-ms`** on `&{/firmware/scmi}`, sized from option 1 | In the binding (`arm,scmi.yaml:127-132`) and read at probe (`driver.c:3187`). Upstream allows larger values (i.MX: 5000). -9's late replies came within the ~0.44 s window | If CPUCP is really dead, every message waits up to 3 × the value (`shmem.c:107-119` spins 2 ×, then the wait). At 200 ms and -9's 10 timeouts, about 6 s of boot. Not from the stock tree |
| 3 | **Pass criteria and a guard** in `/init`/`attempt.sh`: fail the boot on `Firmware version 0x0` or a missing `quirk_perf_level_get_fc_force` line; never rebind `scmi-cpufreq` in such a boot | Section 4: without the quirk, PERF_LEVEL_GET falls back to the message that crashes the firmware | None |
| 3b | **Optional local patch** (`kernel/patches/`, ADR 0007): declare `perf_level_get_fc_force` with no version range, or with a machine compatible (`quirks.c:307-309` supports `compats`) | Johan's own commit names the SoC-compatible match as the fallback design | One-line patch, local only; it hides the version-read failure but not the timeouts |
| 4 | **A/B diagnostics:** `arm,no-completion-irq` (polling, `driver.c:3202`); `cpuidle.off=1` | Polling separates IRQ delivery from firmware latency; section 1 already points at the firmware. Sibi says the firmware bug depends on idle states (2412.0/06550); whether that also affects reply latency is *inference* | One boot each; polling busy-waits, cpuidle off costs power. Not configs to keep |
| 5 | **Backport an upstream fix** | None found (section 2); the only fix newer than the pin (`readq()`) does not touch the SCMI path | n/a |

## Sources

- **Pinned tree** `~/.cache/gbook/linux-a804c57` at `a804c5742bff`:
  - `drivers/mailbox/qcom-cpucp-mbox.c`
  - `drivers/firmware/arm_scmi/{driver,shmem,quirks,base}.c` and `transports/mailbox.c`
  - `Documentation/devicetree/bindings/firmware/arm,scmi.yaml`
  - `arch/arm64/boot/dts/qcom/hamoa.dtsi`
- **Commit metadata:** GitHub API on `torvalds/linux` (commits by path since 2024-06; `compare` against the
  `v6.11`-`v7.4-rc1` tags).
- **Review threads:** the LKML mirror and infradead pipermail URLs above. The owner's lore search clipping lists the
  full V3-V7 thread (`~/code/obsidian/the build host/Clippings/sx1e80100 Enable CPUFreq.md`).
- **Logs:** attempts -8 and -9 in `dumps/firstboot/2026-11-03-netlog.txt` (gitignored). Summary in
  [`docs/recon/scmi-2026-11-03.md`](../recon/scmi-2026-11-03.md).
- **Stock tree:** `dumps/recovery-16471258/dtbo/entry00-base.dts` ([stock-dtb.md](stock-dtb.md)).

## Update: the cause narrowed, the board DTS changed (2026-11-03, 11:43 PM ET)

The stalls follow the PSCI domain idle states (attempts -27 to -34, [scmi-2026-11-03.md](../recon/scmi-2026-11-03.md)).
Options 3-4 were run: `cpuidle.off=1` (-28) and `arm,no-completion-irq` (-29) each gave 3 of 3 clean cold boots, and
so did removing every `domain-idle-states` (-34). The board DTS now does the last of these
([ADR 0008](../adr/0008-no-psci-domain-idle-states.md)) and keeps the 1000 ms window. An upstream report draft is
in scmi-cpucp-stall-report.md (not sent).
