# Phase 3: the GMU gets a driver, the crypto node goes (2026-11-03)

Attempt `2026-11-03-26` (kernel `#17`, commits `a6e3987` and `63bddc5`, image `963fb3004304e941`), cold start. Owner
pick from the Omarchy review (2026-11-03, "1 2 3"). Sources: the netlog `dumps/firstboot/2026-11-03-netlog.txt` and
the AP console log (gitignored), and Omarchy's `linux-omarchy-aarch64` package
(https://github.com/omacom/omarchy-pkgs/tree/master/pkgbuilds/linux-omarchy-aarch64, read 2026-11-03).

## Why

Every boot left `unbound=3d6a000.gmu` and `unbound=1dfa000.crypto` (the `sync_state() pending due to …` lines that
`/init` reports since the retro), handoff lead 3 and the gap list's crypto lead.
- **GMU:** nothing binds the GPU's management unit, so gcc and gpucc never reach `sync_state()`. Akhil P Oommen's
  (Qualcomm) "drm/msm: Attach a driver to the GMU" series binds it as a component of the GPU master; Omarchy carries it
  as `2170`-`2174` with its own fix-up `2178`.
- **Crypto:** the pin makes QCE depend on `BROKEN` (`drivers/crypto/Kconfig:531`), so nothing binds the node, and
  `aggre2_noc` and `mc_virt` never reach `sync_state()`; Omarchy (`2210`) disables the node.

## Changes

- `kernel/patches/0002`-`0007` (ADR 0007): the six patches unchanged, each with a provenance header. They apply in order
  to the pin; check 20 now applies the series cumulatively to the pin's files (0005-0007 build on 0002-0004).
- `dts/x1e80100-google-mica.dts`: `&crypto { status = "disabled"; }`, marked not from the stock tree; `qcom,qce` left
  `kernel/dt-gaps.txt`.

## Result: pass

- `adreno 3d00000.gpu: bound 3d6a000.gmu (ops a6xx_gmu_bind_ops)` at 0.555 s.
- `unbound=` went from 8 to 6: `3d6a000.gmu` and `1dfa000.crypto` are gone. Left: the four CPU bandwidth-monitor PMUs
  (`24091000`, `240b3400`, `240b5400`, `240b6400`) and the video and camera clock controllers (`aaf0000`, `ade0000`).
- The GPU is unchanged on the `msm.separate_gpu_kms=1` path that patch `0005` reworks: `gpu-node=renderD128
  driver=adreno`, `gpu-open=opened`, `gpu-freq=300000000 max=1250000000`, SQE and GMU firmware loaded, zap off.
- `errors=0` (from 1). SCMI full (`0x20000`, 3 of 3, 78 replies, max 3.9 ms, 0 timeouts).
- Not measured yet: whether suspend now reaches CX collapse and DDR self-refresh (the reason Omarchy carries `2210`);
  there is no suspend test on mica yet.
