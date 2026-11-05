# Debugging the sound card: ASoC, SoundWire and audioreach tools

Research pass by an agent on 2026-11-04 (11:55 PM EST) (from `date` in the writing command), for M3 ticket 16 (the left amplifiers never
enumerate; `docs/recon/audio-2026-11-04.md`). Sources are cited per item: the kernel at `a804c57` (K), the alsa-utils
1.2.16 man pages, alsa-ucm-conf master. Items marked inferred or unverified are that. The first lead (a UCM `PA Volume 12`
cset above the driver's cap) was checked on boot -28: every PA Volume read 6 and `alsaucm` exited 0, so it is not the
cause of the silent pair; the enumerator registers are (the recon note, "The speaker test").

Sources: kernel /home/the owner/.cache/gbook/linux-a804c57 (K), alsa-utils 1.2.16 man pages, alsa-ucm-conf master (installed 1.2.16.1 may differ; check `/usr/share/alsa/ucm2` on the device).

**Lead to run first (inferred, verify on device)**
- Master `ucm2/codecs/wsa884x/four-speakers/SpeakerSeq.conf` sets `cset "name='WooferLeft PA Volume' 12"` (and the other three), plus DAC/COMP/BOOST/PBR=1, VISENSE=0, WSA MODE=0 per amp. `K/sound/soc/qcom/x1e80100.c:46-51` caps all six `* PA Volume` at 6 (0 dB on `pa_gain` -9 dB/1.5 dB steps, wsa884x.c:1732) and `WSA[2] WSA_RX0/1 Digital Volume` at 81 (-3 dB). `SOC_SINGLE_RANGE_TLV` puts through `snd_soc_put_volsw` (soc.h:94), whose `soc_mixer_valid_ctl` (soc-ops.c:155) returns -EINVAL above `platform_max`, so a cset of 12 fails. What alsaucm does after a failed cset, and the installed file's ordering (per amp would leave later amps without `DAC Switch`; per control would not) are unverified. Check: `grep -rn 'PA Volume' /usr/share/alsa/ucm2/codecs/wsa884x/` (value and order); `alsaucm -n -b -` with `open <name from alsaucm listcards>`, `set _verb HiFi`, `set _enadev Speaker`, `list1 _enadevs`, watching stderr; `amixer -c0 contents | grep -A2 -E 'PA Volume|DAC Switch'` for per-amp values and the reported max.

**ASoC debugfs** (`K/sound/soc/soc-core.c:135-216`, `soc-dapm.c:2470-2600`, `soc-pcm.c:275-300`)
- `/sys/kernel/debug/asoc/components`, `.../dais`: every registered component and DAI name.
- `/sys/kernel/debug/asoc/<card>/<component>/dapm/<widget>`: `<name>: On|Off [(forced)]  in N out N` (`w->power`; N = connected endpoints), `stream <name> active|inactive`, `widget-type`, then one ` in|out  "<path>" "<peer widget>" "<peer component>"` per path with `connect` true: a missing expected line means a disconnected route. `.../dapm/bias_level` per component and card. Diff an audible amp's widgets against a silent one's (prefix from DT `sound-name-prefix`, soc-core.c:1418).
- `/sys/kernel/debug/asoc/<card>/<FE dai_link>/state`: DPCM state with each connected BE's negotiated Hardware Params (channels, rate): the only view of what `WSA_CODEC_DMA_RX_0` runs under the `MultiMedia2` FE. `/proc/asound/card0/pcm1p/sub0/hw_params` is the FE side only (`designs/procfile.rst:130`).
- `/sys/kernel/debug/asoc/dapm_pop_time` (ms, soc-core.c:216): non-zero logs every DAPM widget power event to dmesg (soc-dapm.c:173), cheaper than ftrace.
- `/sys/kernel/debug/regmap/<sdw dev>/registers`, `cache_only`: one per amp (`devm_regmap_init_sdw`, wsa884x.c:2103); diff a silent vs audible amp. `cache_only` is 1 until ATTACHED and again on runtime suspend (:1548-1556, :2139), so read it during playback.

**SoundWire** (`K/drivers/soundwire/debugfs.c`, `sysfs_slave.c:222-246`, `qcom.c`)
- `/sys/kernel/debug/soundwire/master-<ctrl>-<link>/<sdw:…>/registers`: `Register  Value` table (DP0, SCP, DP1..14 banks 0/1; `XX` = read failed; the read resumes the device). Compare DPn CHANNELEN of quiet amps. `/sys/bus/soundwire/devices/sdw:*/status` (`Unattached|Attached|Alert`) and `device_number`. Caveat (2026-11-04/05): that
  status follows the driver's last enumeration event, not the hardware; it read `UNATTACHED` while two units played and
  `Attached` after they were lost. The masters' enumerator registers decoded by `scripts/swrm_enum.py` (or
  `scripts/audio-state.sh`) are the truth.
- `no slave alert found.spurious interrupt` (qcom.c:739): `SLAVE_PEND_IRQ` fired but no device in `SWRM_MCP_SLV_STATUS` is in Alert; ratelimited, harmless by itself. `SWR bus clsh detected` (qcom.c:760): `MASTER_CLASH_DET`; the driver masks that interrupt after the first hit, so it logs once; follow up with `status`/`registers`.
- `qcom,port-mapping` (`bindings/sound/qcom,wsa8840.yaml:35`, wsa884x.c:2089, qcom.c:1179): 6 u32s in slave port order (DAC, COMP, BOOST, PBR, VISENSE, CPS; wsa884x.c:798-805), each the controller port whose `qcom,ports-*` config that codec port takes; absent = positional fallback. A wrong map silences amps without errors.

**Tracing and dyndbg** (`K/include/trace/events/asoc.h`, `Documentation/trace/events.rst:45-56`, `admin-guide/dynamic-debug-howto.rst:249-269`, kernel-parameters.txt:7684)
- Boot: `trace_event=asoc:*` (`snd_soc_dapm_widget_power`, `snd_soc_dapm_path`, `snd_soc_dapm_connected`, ...); runtime `echo 'asoc:*' > /sys/kernel/tracing/set_event`, read `/sys/kernel/tracing/trace`. `snd_pcm:*` needs `CONFIG_SND_DEBUG` (`designs/tracepoints.rst`). SoundWire has no tracepoints.
- `dyndbg="file drivers/soundwire/bus.c +p; file drivers/soundwire/qcom.c +p; file sound/soc/codecs/wsa884x.c +p"` on the command line, or the same query into `/proc/dynamic_debug/control`. Yield at a804c57: `bus.c` is rich (enumeration, dev_num, PING status, clock stop); `qcom.c` has 3 sites, `wsa884x.c` 2; `lpass-wsa-macro.c`, `q6apm.c`, `topology.c`, `audioreach.c` have no `dev_dbg`, so dyndbg there shows nothing.

**Topology** (`K/sound/soc/qcom/qdsp6/topology.c:1415-1445`)
- Loaded from `qcom/<card->driver_name>/<card->name>-tplg.bin` (`q6apm.c:841`); no debugfs of its own; its widgets/routes appear in the q6apm component's `dapm/`. Decode offline: `alsatplg -d <bin> -o <out.conf>`.

**alsa-utils** (man pages 1.2.16)
- `speaker-test -D hw:0,1 -c 4 -t wav -s N` for N 1-4 (`-s` one channel; `-t wav` speaks the channel name) and `-m FL,FR,...`; the card's 4-channel map is FL, LB, FR, RB by index (x1e80100.c:110-115, DSP positions; physical amp per index unverified). Read the pattern: both silent amps on one bus (`WSA` vs `WSA2`) points at bus config (ports, port-mapping, BE params); one woofer plus one tweeter points at per-amp control state.
- `aplay -v` prints the hw/sw params actually set; `--dump-hw-params` lists the device capabilities.
- `amixer -c0 contents` (all controls, values, limits), `cget`; from a script, address a control whose name has spaces by
  `numid=N` (`amixer cset name="WSA WSA_RX0 Digital Volume" 0` found nothing on 2026-11-04 and the mute test was void;
  `numid=21` worked); `alsaucm -c <name> list _verbs`, `list _devices/HiFi`, `list1 _enadevs`, `set _enadev Speaker` (batch `-n -b -`).
- `/usr/sbin/alsa-info --no-upload --stdout --with-amixer` (Debian path): one-shot snapshot of cards, mixer, dmesg, `/proc/asound`.

**WSA884x specifics** (`K/sound/soc/codecs/wsa884x.c`)
- hwmon `wsa884x` per amp (`/sys/class/hwmon/hwmon*/name`, `temp1_input` milli-degrees, :2114); measured only with the PA off, cached value while playing (:1873): four instances prove enumeration, not playback.
- Controls: `PA Volume` (0-31 raw, capped 6), `WSA MODE` (Speaker/Receiver), `DAC|COMP|BOOST|PBR|VISENSE|CPS Switch` (:1740-1750, each enables one SoundWire port; VISENSE = V/I sense). DAPM map: only `SPKR <- IN` (:1754).

## The downstream driver (research pass, 2026-11-05 (12:27 AM EST))

Source: CodeLinaro `audio-kernel-ar`, branch `audio-kernel.lnx.6.0.r67-rel` (no x1e80100 branch exists there; 6.12.r4 has the
same probe logic): `https://git.codelinaro.org/clo/la/platform/vendor/qcom/opensource/audio-kernel-ar/-/blob/audio-kernel.lnx.6.0.r67-rel/<path>`.
Read for ticket 16 against the stock log `dumps/firstboot/2026-11-05-stock-lastkmsg-swr.txt`.

- **`wsa884x_swr_probe`** (`asoc/codecs/wsa884x/wsa884x.c:1989-2045`): supplies on, the `spkr-sd-n-node` active state, a 5 ms
  sleep "for soundwire auto enumeration", then `swr_get_logical_dev_num()`; a failure is `dev_dbg` only and the probe defers.
  `VPHX EN Status` (`wsa884x_validate_dt_configuration_params`, :1130-1138) is a codec register read over SoundWire
  (`WSA884X_VPHX_SYS_EN_STATUS`, `wsa884x-registers.h:323`) from the ASoC component probe, which runs only after the device
  number was assigned: a VPHX line for `0220` proves that amplifier enumerated on stock; its "devnum assigned" line fell
  outside the pstore window.
- **`swrm_get_logical_dev_num`** (`soc/swr-mstr-ctrl.c:2860-2931`): reads the hardware enumerator table (0x530/0x534 + 8*i)
  for `i = 1..qcom,swr-num-dev` (2 per bus on stock mica, `entry00-base.dts:17647,17716`), matches `addr` exactly, requires the
  `SWRM_MCP_SLV_STATUS` slot to read attached or alert; no retry inside; "device 0x%llx is not ready" on failure (`dev_err`).
- **`AUTO_ENUM_FAILED`** (`swr-mstr-ctrl.c:2675-2687`): the downstream IRQ handler writes `SWRM_ENUMERATOR_CFG` 0, waits for
  `SWRM_ENUMERATOR_STATUS` idle, writes 1 (re-arms the hardware enumerator). Mainline `drivers/soundwire/qcom.c` at `a804c57`
  only defines the bit (`:62`). `CHANGE_ENUM_SLAVE_STATUS` goes to `swrm_process_change_enum_slave_status` (:2431-2500).
  Bus clash handling matches mainline (mask the interrupt after the first hit).
- **Unique id**: downstream `reg = <0x4 0x2170220>`/`0x2170221` is the same 48-bit id mainline byte-swaps out of the two
  registers; the last digit is `unique_id` 0 or 1 (`speaker@0,0`/`@0,1`). Neither driver handles two slaves with equal ids;
  no `SWR_ID` strap code exists in `wsa884x.c`. Qualcomm's pineapple reference pairs the shutdown pin by unique id
  (`wsa_spkr_en02` for both `0220`s, `wsa_spkr_en13` for both `0221`s; `audio-devicetree`
  `pineapple-audio-overlay.dtsi:218/237/296/315`), where stock mica pairs it by bus (`entry00-base.dts:17662/17679/17731/17748`),
  as `dts/diag/sound.dtsi` does. A disabled `swr_haptics@f0170220` sits on stock swr3 (:17615-17621).
