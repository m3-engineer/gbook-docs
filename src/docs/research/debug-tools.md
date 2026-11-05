# Debug tools for the next boots: SCMI timeouts and the touchscreen `0xff` reads

Researched 2026-11-03 from the kernel tree at the pin (`~/.cache/gbook/linux-a804c57`, `a804c5742`), the build
config `~/.cache/gbook/build-a804c57/.config` (kernel `#13` era), the pinned Debian `busybox-static`, the netlog
`dumps/firstboot/2026-11-03-netlog.txt` (gitignored) and the GitHub page of `morluto/rea`. The device was not
touched. Line numbers are at the pin unless a repo path is given. *Inference* marks what the source does not state.

## Ranked recommendation for the next boot

| # | Add | Problem | Cost |
|---|---|---|---|
| 1 | Event tracing: two config lines, `trace_event=` on the command line, trace dump into the netlog | both | one kernel rebuild (~5 min); 0 owner time per boot |
| 2 | `log_buf_len=4M` | both | none |
| 3 | IRQ counts, pin and regulator state in `/init` | both | none (sysfs, debugfs, `/proc` reads) |
| 4 | Raw `i2ctransfer` reads of the touchscreen's HID descriptor | touch | none; **needs the owner's OK** (I2C writes of a register pointer) |
| 5 | `dyndbg` on the silent i2c-hid and GENI error lines | touch | none (`GBOOK_CMDLINE_EXTRA`) |

**1. Kernel fragment** (a new `kernel/mica-debug.config`; it sorts after `mica-firstboot.config`):

```
# Event tracing (tracefs, trace_event=). arm64 defconfig:1970 sets "# CONFIG_FTRACE is not set".
CONFIG_FTRACE=y
CONFIG_ENABLE_DEFAULT_TRACERS=y
# require: EVENT_TRACING
```

`olddefconfig` on a scratch copy of the build config with these two lines adds only `TRACING`, `EVENT_TRACING`,
`RING_BUFFER`, `TRACEPOINTS`, `NOP_TRACER`, `CONTEXT_SWITCH_TRACER`, `TRACEFS_AUTOMOUNT_DEPRECATED`,
`BRANCH_PROFILE_NONE`, `UPROBES`, `UPROBE_EVENTS`, `EPROBE_EVENTS`, `BPF_EVENTS`, `DYNAMIC_EVENTS`, `PROBE_EVENTS`
and the module-only `IWLWIFI_DEVICE_TRACING`. No `FUNCTION_TRACER`, so no per-function patch sites. The probe-event
extras can be pinned off with `# CONFIG_UPROBE_EVENTS is not set` (and `EPROBE_EVENTS`, `BPF_EVENTS`) for a leaner
image. `EVENT_TRACE_STARTUP_TEST` stays off.

**Command line** (`GBOOK_CMDLINE_EXTRA`, one line; the -18 boot proved a quoted `dyndbg=` survives packaging):

```
log_buf_len=4M trace_event=scmi:scmi_xfer_begin,scmi:scmi_xfer_response_wait,scmi:scmi_rx_done,scmi:scmi_xfer_end,scmi:scmi_msg_dump,i2c:*,qcom_geni_i2c:* dyndbg="file i2c-hid-core.c line 1055 +p; file i2c-qcom-geni.c line 235-306 +p"
```

**`/init` additions** (sketch; the SCMI awk was tested on a synthetic trace only):

```sh
# After the sysfs mount:
mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null
T=/sys/kernel/tracing

# Before the touch window (after touch-input). Adapter numbers follow probe order, so resolve them.
i2c_bus() { for b in /sys/bus/i2c/devices/i2c-*; do case "$(readlink -f "$b")" in */"$1"/i2c-*) echo "${b##*i2c-}"; return ;; esac; done; }
ts_bus=$(i2c_bus a80000.i2c); tp_bus=$(i2c_bus b80000.i2c)
cap i2c-bus "touchscreen=i2c-${ts_bus:-none} touchpad=i2c-${tp_bus:-none}"
cap irq-counts "$(grep -E 'apss_cpucp_mbox|a80000\.i2c|b80000\.i2c|hid-over-i2c' /proc/interrupts | tr -s ' ')"
cap ts-pins "$(grep -E '^ gpio(32|33|48|51|88|89) +:' /sys/kernel/debug/gpio 2>/dev/null)"
for r in /sys/class/regulator/*; do
  [ "$(cat "$r/name" 2>/dev/null)" = vreg_touchscreen_3p3 ] && cap ts-vreg "state=$(cat "$r/state") users=$(cat "$r/num_users")"
done
# (item 4 goes here, before the snapshot, so its transfers are in the trace too)
# Keep SCMI, the two touch buses and their GENI controllers; drop i2c10 (TPM) and the other buses.
trace_keep() { grep -E "entries-in-buffer|scmi_|geni_i2c_[a-z_]+: (a80000|b80000)\.i2c|i2c_[a-z]+: i2c-(${ts_bus:-x}|${tp_bus:-x}) " "$T/trace" | redact; }
trace_keep >/tmp/trace-probe.txt # before the touch window floods the ring
cap trace "$(head -n 1 /tmp/trace-probe.txt) kept=$(wc -l </tmp/trace-probe.txt)"
cap geni-setup "$(grep -o 'geni_i2c_bus_setup: .*' /tmp/trace-probe.txt | sort -u)"
cap geni-err "$(grep -o 'geni_i2c_err: .*' /tmp/trace-probe.txt | sort | uniq -c)"
cap scmi-latency "$(awk '{t=""; s=""; for (i = 1; i <= NF; i++) { if ($i ~ /^[0-9]+\.[0-9]+:$/) t = substr($i, 1, length($i) - 1); if ($i ~ /^seq=/) s = $i }
  /scmi_xfer_begin:/ { b[s] = t }
  /scmi_rx_done:/ && (s in b) { d = (t - b[s]) * 1000; n++; if (d > m) m = d }
  /scmi_xfer_end:/ && / s=-110 / { to++ }
  /t=!RESP/ && (s in b) { late = late sprintf(" %s:%.0fms", s, (t - b[s]) * 1000) }
  END { printf "replies=%d max=%.1fms timeouts=%d late=%s\n", n, m, to, (late == "" ? " none" : late) }' /tmp/trace-probe.txt)"

# In the netlog block, after the dmesg section (never through say/cap: the console runs at 115200 baud):
#   echo "--- trace at probe"; cat /tmp/trace-probe.txt; echo "--- trace at end"; trace_keep
```

What one boot then answers:
- **SCMI:** the reply latency of every message (`scmi_xfer_begin` to `scmi_rx_done`), the arrival time of each late
  reply (`!RESP` dump), and with the `apss_cpucp_mbox` IRQ count next to the `sent_ok`/`response_ok` counters
  already in `/init`, whether the interrupts arrive late or not at all. That sizes `arm,max-rx-timeout-ms` from data
  ([scmi-cpucp-timeouts.md](scmi-cpucp-timeouts.md), ranked step 1-2).
- **Touch:** the bytes on the wire per read (`i2c_reply`), the GENI status of every interrupt during it
  (`geni_i2c_irq`: `m_stat` and `rx_st`, whose low bits are the RX FIFO word count), any controller error
  (`geni_i2c_err`), and the SCL counters actually programmed (`geni_i2c_bus_setup`).

Not for the next boot: `tp_printk`, `ftrace_dump_on_oops`, `initcall_debug`, the function tracer, SCMI raw mode,
`i2cdetect`/`i2cdump`/`i2cget` (reasons below). Housekeeping: `softlockup_panic=1` on the base command line does
nothing in this build (section 6).

## 1. Event tracing from an initramfs

**State today.** `CONFIG_FTRACE` is not set (`.config:12029`; `arch/arm64/configs/defconfig:1970`), so there is
no tracefs and no trace event in the current kernel. `FTRACE` defaults to `y if DEBUG_KERNEL`
(`kernel/trace/Kconfig:204-207`), but defconfig turns it off explicitly. `ENABLE_DEFAULT_TRACERS` selects `TRACING`
(`:588-591`), and `TRACING` selects `EVENT_TRACING`, `RING_BUFFER` and `TRACEPOINTS` (`:179-188`).

**Command-line parameters** (all `[FTRACE]`, `Documentation/admin-guide/kernel-parameters.txt:7628-7700`):

| Parameter | Handler | Use here |
|---|---|---|
| `trace_event=<list>` | `trace_events.c:4659` | the capture. Comma-separated `system:event`, `system:*` |
| `trace_buf_size=nn[KMG]` | `trace.c:1035` | per CPU; default 1 441 792 bytes (`trace.c:740`). Default is enough with the snapshot before the touch window |
| `tp_printk` | `trace.c:354` | events also to printk. Not now: see below |
| `tp_printk_stop_on_boot` | `trace.c:361` | stops `tp_printk` at `late_initcall_sync` |
| `ftrace_dump_on_oops[=orig_cpu]` | `trace.c:296` | dumps the ring to the console on an oops. Not now |
| `trace_trigger=`, `trace_instance=` | `trace_events.c:3854`, `trace.c:320` | not needed |

**Armed before the SCMI probe.** `start_kernel` calls `trace_init()` (`init/main.c:1086`), which runs
`trace_event_init()` (`trace_events.c:4987`) and `event_trace_enable()`, which enables the `trace_event=` list
(`:4884-4912`) and again at `early_initcall` (`:4932-4946`). arm-scmi binds at about 0.36 s, so its first message is
in the ring.

**Events at the pin** (all built in, so `trace_event=` reaches them):
- `scmi` (`include/trace/events/scmi.h`): `scmi_xfer_begin` (`:37`, called `driver.c:1429`),
  `scmi_xfer_response_wait` (`:65`, `driver.c:1349`, prints the timeout in ms), `scmi_rx_done` (`:121`,
  `driver.c:1164` for replies), `scmi_xfer_end` (`:93`, `driver.c:1467`, prints the return code),
  `scmi_msg_dump` (`:147`, with payload; a reply for an xfer that already timed out is dumped as `!RESP` through
  `scmi_bad_message_trace`, `driver.c:867-891`, from the "Message for %d … is not expected" path, `:1015-1021`).
  Leave out `scmi_fc_call` (`:12`): it fires on every FastChannel perf level set (`perf.c:708`), each cpufreq change.
- `i2c` (`include/trace/events/i2c.h`): `i2c_read`, `i2c_write`, `i2c_reply`, `i2c_result`, emitted around every
  `__i2c_transfer` (`i2c-core-base.c:2283-2307`) once the event's static key is on. `i2c_reply` records the bytes
  read; the text output shows the first 64 (`%*phD`, capped in `lib/vsprintf.c:1205`): the whole 30-byte HID
  descriptor, the first 64 of the 935-byte report descriptor.
- `smbus` (`include/trace/events/smbus.h`): only SMBus calls; i2c-hid uses `i2c_transfer`, so not needed.
- `qcom_geni_i2c` (`include/trace/events/qcom_geni_i2c.h`, created in `i2c-qcom-geni.c:4-5`):
  `geni_i2c_bus_setup` (`i2c-qcom-geni.c:263`), `geni_i2c_irq` (`:344`, every interrupt), `geni_i2c_err` (`:299`,
  every error, including NACKs and timeouts that `dev_err` skips).
- `qcom_geni_se`: `geni_se_regs` dumps 50 SE registers, but only `spi-geni-qcom.c` emits it, not the I2C driver.
- `hid`, `i2c-hid`: no trace events at the pin.
- GPI DMA: no events; and `QCOM_GPI_DMA=m` (`.config:8490`), so these GENI I2C buses run FIFO / SE DMA.

**Why not `tp_printk`.** It copies every enabled event to printk; with `ignore_loglevel` they go to the 115200-baud
console. The kernel doc warns it can live-lock with high-frequency events (`kernel-parameters.txt:7644-7648`), and
the touchpad alone gave 841 to 4055 reports per window (`attempts.tsv`, -18, -19). Console output inside the SCMI
window could also change the timing under study (*inference*). Fallback only for a boot that never reaches the
netlog, and then with `trace_event=scmi:*` alone plus `tp_printk_stop_on_boot`. `ftrace_dump_on_oops` writes the
whole ring to the same console: neither problem is an oops, so skip it.

**Timestamps.** The default `local` trace clock is `sched_clock()` (`trace_clock.c:37-42`, `trace.c:1077`), so trace
times line up with the dmesg times (*inference*: arm64 printk also uses `sched_clock`).

**Later, if useful.** `BOOTTIME_TRACING` (`Kconfig:226`) adds per-event filters at boot through a bootconfig in the
initrd. A persistent ring buffer (`reserve_mem=… trace_instance=…@…`, `kernel-parameters.txt:7734-7758`) survives a
warm reset, but the next boot is usually stock, so it is of little use here.

## 2. The printk ring wraps

`CONFIG_LOG_BUF_SHIFT=17` (`.config:162`) gives a 128 KiB ring. In the netlog, two of the last six boots' dmesg
sections hold about 126 KB of text and start mid-boot (first line `GICv3: …` and `KASLR enabled`, not
`Booting Linux`): the earliest lines were lost. Any added `dyndbg` makes this worse. `log_buf_len=` is an
`early_param` (`kernel/printk/printk.c:1071`); 4M costs 4 MiB of RAM.

## 3. Read-only `/init` captures (no rebuild)

- **`/proc/interrupts`.** The CPUCP mailbox IRQ is `apss_cpucp_mbox` (`qcom-cpucp-mbox.c:175-176`); each GENI I2C
  IRQ carries its device name, `a80000.i2c` for the touchscreen bus (`i2c-qcom-geni.c:1201-1202`). The SCMI
  research doc could not tell lost interrupts from slow firmware (its section 1); an IRQ count against
  `sent_ok`/`response_ok` and the late replies does.
- **Pins, `/sys/kernel/debug/gpio`.** `msm_gpio_dbg_show_one` prints direction, level, function, drive and pull per
  pin (`pinctrl-msm.c:654-716`) and skips `gpio-reserved-ranges` (`:683`), so reading it does not touch secure
  pins. It reads TLMM registers only. Pins: SDA/SCL `gpio32`/`gpio33` (`hamoa.dtsi:6180-6186`, 2 mA,
  `bias-pull-up`), IRQ `gpio51`, reset-n `gpio48` and report-enable `gpio89` (both `output-low`, as in the stock
  overlay `entry01-overlay.dts:1085-1094`), VDD enable `gpio88`.
- **Regulator.** `vreg_touchscreen_3p3` is `regulator-boot-on`, not `always-on` (`dts/x1e80100-google-mica.dts:336-352`).
  Its state tells whether the panel is powered when the raw read runs.
- **Clock table.** `geni_i2c_bus_setup` prints `clk_div`: 2 means the 19.2 MHz table `{2, 5, 11, 22}`
  (`i2c-qcom-geni.c:188`), 4 the 32 MHz table `{4, 3, 9, 19}` (`:196`), which the driver avoids unless the clock
  already runs at 32 MHz, because it "breaks I2C transfers on X1E80100 CRD" (`:207-218`). The formula comment
  (`:174-185`) gives, for 19.2 MHz at 400 kHz: t_high = 0.52 µs, t_low = 1.15 µs, SCL ≈ 436 kHz. The comment says
  the firmware adds cycles beyond that formula. *Inference:* by the formula alone, both periods sit under the
  Fast-mode minimums (t_low 1.3 µs, t_high 0.6 µs, NXP UM10204; values from memory, not re-read today). The stock
  side (Qualcomm's vendor driver) needs a device-side read; that is out of scope here.

## 4. Busybox I2C applets and a raw descriptor read

**The applets are there.** The image's busybox is Debian `busybox-static:arm64 1:1.38.0-3+b1`
(`scripts/package-in-container.sh:9`). `~/.cache/gbook/out/` held no initramfs during this research, so the same
package was fetched from `deb.debian.org` (sha256 `968d1aa8f579fa1ac59c26afa365454369e13cf29848e6400b50028fed0ffda0`;
compare with `manifest.txt` on the next packaging) and listed under `qemu-aarch64-static`: `i2cdetect i2cdump i2cget
i2cset i2ctransfer`, plus `devmem`, `xxd`, `hexdump`, `nc`, `timeout`. `CONFIG_I2C_CHARDEV=y` (`.config:3896`) and
devtmpfs give `/dev/i2c-N`.

**Which applet.** Only `i2ctransfer` (`i2ctransfer [-fay] I2CBUS {rLEN[@ADDR] | wLEN[@ADDR] DATA…}…`) can issue
HID-over-I2C's 16-bit register write and read in one transfer with a repeated start, as
`i2c_hid_read_register` does (`i2c-hid-core.c:200-243`). `i2cget` and `i2cdump` use 8-bit SMBus commands, wrong
for this device. `i2cdetect` probes every address with SMBus quick writes by default (`-q`), and `i2cset` writes;
use neither. `i2cdetect -l` (list adapters, no bus traffic) is safe.

**When the read is meaningful.** If i2c-hid's own probe fails, it powers the panel down (`i2c-hid-core.c:1320-1324`),
and the regulator turns off when its last user disables it (`regulator/core.c:3269-3270`): a raw read would then
only NACK. In -17 and -18 the failure (`usage index exceeded`, `hid-core.c:266`) came later, in the HID driver's
report parse; i2c-hid stayed bound, its IRQ kept counting, so the panel stayed powered (*inference* from -17's IRQ
count 1 to 730). So run it only while `/sys/bus/i2c/devices/<bus>-0010/driver` exists, with `-f` (the address is
busy). `i2c_transfer` holds the adapter lock for the whole transfer (`i2c-core-base.c:2346-2352`), so it cannot
interleave with an i2c-hid read mid-transfer.

```sh
ts_dev=/sys/bus/i2c/devices/${ts_bus}-0010
if [ -n "$ts_bus" ] && [ -e "$ts_dev/driver" ] && [ -c "/dev/i2c-$ts_bus" ]; then
  for n in 30 30 16 20 24 32; do # 30: FIFO path, as at probe; 32 and up: SE DMA (i2c-qcom-geni.c:528, i2c-core-base.c:2684)
    cap ts-raw "desc r$n $(i2ctransfer -f -y "$ts_bus" w2@0x10 0x00 0x00 r$n 2>&1 | tr '\n' ' ')"
  done
  cap ts-raw "rdesc r64 $(i2ctransfer -f -y "$ts_bus" w2@0x10 0x21 0x00 r64 2>&1 | tr '\n' ' ')" # wReportDescRegister 0x21
else
  cap ts-raw "skipped: bus=${ts_bus:-none} driver=$(basename "$(readlink "$ts_dev/driver" 2>/dev/null)" 2>/dev/null)"
fi
```

Safety (*inference* from the HID-over-I2C read path above): the two written bytes only set the register pointer, as
i2c-hid's own descriptor fetch does; register `0x0000` here is the HID descriptor and `0x0021` the report
descriptor (the -18 dump), both read-only. Still an I2C write by an agent's script, so it needs the owner's OK
(CLAUDE.md). What it separates: a cut at byte 20 for every length points at the device or the bus; a cut that moves
with the length, or only on one path (FIFO vs DMA), points at the controller.

## 5. GENI error prints and `dyndbg`

- `geni_i2c_err` (`i2c-qcom-geni.c:291-313`) logs `dev_err` only for bus-protocol, arbitration, overrun, illegal
  command and the GP_IRQ errors, followed by `geni_i2c_err_misc`'s register dump (`:269-289`: `m_cmd`,
  `geni_status`, `geni_ios`, FIFO/DMA status), whose lines are `dev_dbg`. NACK, abort and timeout are `dev_dbg` only
  (`:302-307`) and skip the register dump even with `dyndbg` on. The error table is at `:152-164` (`-ENXIO` address
  NACK, `-EPROTO` bus protocol, `-EAGAIN` arbitration, `-ETIMEDOUT`).
- `dyndbg` line range `235-306` covers "I2C clk selected" (`:235`, the `clk_idx`) and every error line, but not
  `:368`, which prints on every SE DMA interrupt (the touchpad's 47-byte reports) and would flood the console. Line
  ranges are in the `dyndbg` grammar (`Documentation/admin-guide/dynamic-debug-howto.rst:131-142`).
- `i2c-hid-core.c:1055` is the silent "nothing at this address" that -19 could not see.
- Probe-time `dev_err`s in `qcom-geni-se.c` cover clocks, interconnect, OPP and SE firmware load (`:932-1649`);
  none is a transfer diagnostic. There is no GENI debugfs at the pin.

## 6. Other per-boot aids

- **`softlockup_panic=1` is dead.** `SOFTLOCKUP_DETECTOR`, `HARDLOCKUP_DETECTOR`, `DETECT_HUNG_TASK` and
  `WQ_WATCHDOG` are all off (`.config:11947-11951`). `kernel/watchdog.c`, which owns the parameter (`:428`), is built
  only with `LOCKUP_DETECTOR` (`kernel/Makefile:105`). Every netlog boot logs it under "Unknown kernel command line
  parameters". Either drop it from `package-in-container.sh:10` or add `CONFIG_SOFTLOCKUP_DETECTOR=y` (then
  `DETECT_HUNG_TASK` defaults on, `lib/Kconfig.debug:1229`, 120 s). Neither open problem is a hang, so low priority.
- **`initcall_debug`** (`init/main.c:795`) prints two lines per initcall to the console. The same data costs nothing on
  the console as `initcall:initcall_start,initcall:initcall_finish` (`include/trace/events/initcall.h:27,48`) in
  `trace_event=`. Useful only for the probe-order question from -19.
- **pstore/ramoops**: already built in and mounted by `/init`; it covers the panic and console of a failed boot.
- **SCMI raw mode** (`ARM_SCMI_RAW_MODE_SUPPORT`, `arm_scmi/Kconfig:33-46`) injects messages to the firmware and
  inhibits the normal stack: a write path, not a diagnostic for this project.
- **`GENERIC_IRQ_DEBUGFS`** (off, `.config:75`) would show per-IRQ trigger and state; `/proc/interrupts` covers the
  question for now.

## 7. `morluto/rea`: no

Fetched 2026-11-03 (GitHub page and raw `README.md`, HTTP 200). REA ("Reverse Engineer Anything") is an MCP server
and CLI that gives a coding agent reverse-engineering tools: native binaries through an existing Hopper, Ghidra, IDA
or Kuna, JavaScript/Electron, .NET, Android APKs over adb, websites, packet captures, firmware images through Binwalk
or Unblob. README: "REA connects your agent to tools for inspecting native binaries, JavaScript and Electron apps,
.NET assemblies, and websites." It is a Node.js package (`rea-agents`, Node 22.x/24.x/26.12.1+), MIT, run on the
host (`npx rea-agents setup`). The last-commit date did not render in the fetch.

Fit with this setup:
- It runs on a workstation, not on the target: it needs Node.js and npm, which an aarch64 busybox initramfs has
  not, and it has no I2C, SCMI, device-tree, serial-console or kernel-tracing feature. Its only Linux-kernel feature
  is static inspection of `.ko` modules; this kernel builds none.
- Both open problems sit in the running kernel's view of hardware (reply latency, bytes on the wire); a static
  analyser of binaries does not observe either.
- Where it could help at all: reading a stock vendor binary on the build host (for example the vendor GENI I2C driver's
  timing table) through Ghidra. That runs on the build host, and ADR 0005 keeps vendor content out of git.

Verdict: **no** for the boot loop. A **maybe**, later and off-device, only if the project decides to
reverse-engineer a stock vendor binary; nothing in its README shows aarch64 kernel-module support.

## Update: the wake trace (2026-11-03, 10:50 PM ET)

For the late SCMI completion IRQ ([scmi-2026-11-03.md](../recon/scmi-2026-11-03.md), attempts -28 to -30):
`GBOOK_CMDLINE_EXTRA="trace_event=irq:irq_handler_entry,power:cpu_idle,timer:hrtimer_expire_entry"`. A second
`trace_event=` appends to the first (`setup_trace_event()`, `trace_events.c:4644-4649` at `a804c57`). When
`power:cpu_idle` is on the command line, `/init`'s probe-time capture also keeps CPU 0's `cpu_idle`,
`irq_handler_entry` and `hrtimer_expire_entry` lines (the end copy does not, to keep the netlog short).
`attempt.sh trace wake [ms]` prints, per slow reply, CPU 0's idle state before the `apss_cpucp_mbox` interrupt and what
woke it. `cpu_idle state=` is the cpuidle state index on CPU 0, not the cluster or system domain state.
- Attempt -31 (10:58 PM ET): with the default ring (`TRACE_BUF_SIZE_DEFAULT` 1441792 bytes per CPU, `trace.c:740`)
  the probe snapshot kept 604908 of 1255636 events and lost the SCMI probe. The wake trace needs
  `trace_buf_size=8M` too (per CPU, `set_buf_size()`, `trace.c:1020`; 96 MB over 12 CPUs).

## Update: the fast sweep (2026-11-04, 9:21 PM EST)

A boot whose stick carries ROOT takes `/init`'s fast sweep (task #24, `.scratch/m3-rootfs/issues/14-fast-sweep.md`). It
keeps the trace: the same `trace_event=` ring, the probe copy from `trace_snapshot` (now at about 32 s, 586 lines kept
on 2026-11-04-24, since no touch window floods the ring) and the end copy in the netlog, so `attempt.sh trace scmi` and
`trace i2c` read a fast boot as before. Gone on the fast sweep: the `*-dmesg` captures (the console has the printk
lines live, the netlog's dmesg section has them all), the prompts and settles. `GBOOK_CMDLINE_EXTRA=gbook.sweep=full`
brings the M2 sweep back on a ROOT stick.
