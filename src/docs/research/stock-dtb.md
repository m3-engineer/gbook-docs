# mica's stock device tree

Extracted 2026-10-21 on the build host from Google's public recovery image. The device was not touched. The DTBs themselves
stay in `dumps/` (gitignored, vendor content). This note keeps how to reproduce them, their hashes and what they
show.

## Source

| Item | Value |
|---|---|
| URL | `https://dl.google.com/device/recovery/mica-user/16471258/recovery.zip` (Last-Modified 2026-10-05 15:44 GMT [11:44 EDT]) |
| `recovery.zip` | 7,601,764,157 bytes, sha256 `cb68dd6dbd73e568cfeecca0cbd4ceb23338640814dc3ee52aba5507e5a645d7` |
| Contents | one file, `android-desktop_signed_recovery_image.bin` (19,230,966,272 bytes, dated 2026-09-29), a GPT disk image |
| Build (AVB props in `vbmeta_a`) | `Dell/mica/mica:17/CL3B.260622.273.R1/16471258:user/release-keys`, rollback index 1339 (location 0) |
| Installed build (recon 2026-10-21) | `…/CL3B.260622.276.R2/16560795`: **newer than this image** |

Reproduce: `scripts/extract-stock-dtb.sh dumps/recovery-16471258/recovery.zip`. It needs `unzip`, `sfdisk`,
`lz4` and `dtc`, and uses `scripts/dtbo_split.py`.

## Partition table (from the image's GPT)

The image is a full internal-disk layout: 38 partitions, with A/B pairs for most Android partitions. `_b` twins
are left out below; each has the same size and type as its `_a` partition. Only `vbmeta_b` carries attributes,
`GUID:48,49,50,51,56` (priority 15, successful). The live device boots slot `_b` (`ro.boot.slot_suffix`, recon).
Read with `sfdisk -d`.

| Partition | Size | Type GUID | Note |
|---|---|---|---|
| `ota_recovery_a` | 128 MiB | Linux data |  |
| `KERN-A` | 0 MiB | Linux data |  |
| `KERN-B` | 4 MiB | Linux data |  |
| `ROOT-B` | 32 MiB | Linux data |  |
| `super` | 12288 MiB | Linux data |  |
| `vbmeta_a` | 4 MiB | Android vbmeta |  |
| `init_boot_a` | 8 MiB | Linux data |  |
| `vendor_boot_a` | 32 MiB | Linux data |  |
| `boot_a` | 64 MiB | ChromeOS kernel |  |
| `pvmfw_a` | 4 MiB | Linux data |  |
| `dtb_a` | 2 MiB | Linux data |  |
| `dtbo_a` | 8 MiB | Linux data |  |
| `desktop_security_persist` | 16 MiB | Linux data |  |
| `desktop_security_storage` | 32 MiB | Linux data |  |
| `misc` | 4 MiB | Linux data |  |
| `metadata` | 64 MiB | Linux data |  |
| `recovery_a` | 32 MiB | Linux data |  |
| `frp_persist` | 2 MiB | Linux data |  |
| `modem_a` | 350 MiB | Linux data |  |
| `bluetooth_a` | 8 MiB | Linux data |  |
| `dsp_a` | 75 MiB | Linux data |  |
| `keymaster_a` | 10 MiB | Linux data |  |
| `persist` | 32 MiB | Linux data |  |
| `rawdump` | 256 MiB | rawdump |  |
| `userdata` | 4154 MiB | Linux data |  |

Points that matter for the boot path ([chromeos-boot-path.md](chromeos-boot-path.md)):
- `boot_a/b` use the **ChromeOS-kernel** type GUID (`fe3a2a5d-…`).
- `vbmeta_a/b` use the **Android vbmeta** GUID (`88434509-…`). vboot loads Android kernels through it.
- `KERN-A` (1 sector), `KERN-B` (a 4 MiB squashfs) and `ROOT-B` are typed as plain Linux data, so vboot does not
  treat them as kernels.

## Where the DT lives

- `dtb_a` (2 MB) is **all zeros**.
- `dtbo_a` is an Android DT table (magic `d7b7ab1e`, version 1, 3 entries of 32 bytes). Each entry is an
  **LZ4 frame** (`04 22 4d 18`), not a raw DTB.
- That matches depthcharge's Android path, which builds the DT from the `dtbo` table
  ([boot path, route B](chromeos-boot-path.md#route-b-modified-android-gki-boot-image)).

| Entry | Decompressed | Kind | Table fields after size/offset | sha256 |
|---|---|---|---|---|
| 0 | 414,268 B | base, root `compatible = "qcom,x1e80100"`, no `model` | `0x0 0xffff0000 0x3 0x0 0xffffffff 0x0` | `4d019aa922b3d92695bafbc741bd3fd0073454995410a43d98904f4f9dac0f84` |
| 1 | 36,860 B | overlay: the board | `0x0 0xffff0000 0x3 0x0 0xffffffff 0x0` | `ae86b73044c9b6bc2af8318291c62d2cbef53bdbe4eea09cbaecafeccb375e84` |
| 2 | 996 B | overlay: keyboard matrix only | `0x0 0xf0001 0x3 0x0 0xffffffff 0x0` | `678a35b9f776a8aa759e542b5f31dc0a2308e940e5d2e3985e69675de9b1c4fd` |

`dtbo_a.img` sha256: `a94f74e2b9360351a94618699f5e9362984f41a68ac37e16efb81e5cf01d06ba`. The table fields
probably encode board-id and SKU ranges for depthcharge's matcher (`android_dtboimg.c`). The decoding is not
checked yet.

## What it shows

**The base is a Qualcomm vendor tree, not mainline.** It has 608 `compatible` properties (257 distinct). Some
match mainline bindings: `qcom,x1e80100-gcc`, `-dispcc`, `-adsp-pas`, `-cdsp-pas`, `-pcie`, `qcom,pmic-glink`.
Display is downstream (`qcom,sde-kms`, `sde_*` labels), and buses use downstream labels (`qupv3_seN_i2c`).
Remoteproc firmware names are bare (`adsp.mdt`, `cdsp.mdt`), loaded from `/vendor/firmware`. So it is a
**hardware map** (buses, addresses, GPIOs, regulators) for writing a mainline DTS, not something to boot as is.

**Board devices in overlay 1** (bus label as in the stock tree):

| Device | Compatible | Bus / address | Note |
|---|---|---|---|
| Touchpad | `hid-over-i2c` | `qupv3_se0_i2c` @ `0x2c`, `hid-descr-addr 0x20` | vdd from `touchpad-vdd-regulator` |
| Touchscreen | `hid-over-i2c` | `qupv3_se8_i2c` @ `0x10` | LG SW42101M per chromium CL 7743220 |
| GSC (Ti50) | `google,cr50` | `qupv3_se10_i2c` @ `0x50` | mainline `tpm_tis_i2c_cr50` binding |
| ChromeOS EC | `google,cros-ec-spi` | `qupv3_se13_spi` @ CS0 | plus `google,cros-ec-keyb` (8 rows x 18 columns, keymap in overlays 1 and 2) |
| USB-C retimers ×2 | `parade,ps8830` | `qupv3_se3_i2c` @ `0x08`, `qupv3_se7_i2c` @ `0x08` | coreboot says `MAINBOARD_HAS_PS8820_RETIMER`; the DT names the PS8830 binding |
| eUSB2 repeaters ×2 | `nxp,ptn3222` | `qupv3_se5_i2c` @ `0x4f` and `0x4b` | |
| USB-C ports ×2 | `usb-c-connector` | under `ucsi`, connectors 0 and 1 | |
| Fingerprint MCU | `usb18d1,5406` | `usb_mp` port 2 | USB-attached, as coreboot's `FINGERPRINT_VIA_USB` says |
| AP flash | `jedec,spi-nor` | `qspi` CS0 | the 32 MB firmware flash |
| Regulators | `regulator-fixed` | `pp3300-ucam`, `dmic-en`, `fpmcu-vcc`, touchpad/touchscreen vdd, `rtmr0/1-{1p15,1p8,3p3}` | |

The overlay also targets display (`mdss_*`, `sde_edp`, `sde_dp`, `sde_dp1`, eDP HPD on `tlmm` 119), the battery
charger, the USB multiport PHYs, reserved memory (a splash region, and a pKVM protected region for the GIC ITS at
`0x17040000`), and it disables seven `apps_rsc_drv2` children.

## Against the XPS 13 9345 (first pass)

- The 9345 uses `parade,ps8830` retimers too. Mica's two retimers sit on different buses, and mica has no
  USB4/Thunderbolt in Dell's spec (10 Gbps). Compare the 9345's `ps8830` nodes and its USB4 nodes.
- The 9345 has a Dell EC (`dell-xps-ec` work); mica replaces it with `google,cros-ec-spi` and
  `google,cros-ec-keyb`. Battery and charging go through `pmic-glink` on both.
- The 9345's TPM is not a GSC; mica adds `google,cr50` on I2C.
- Camera: the 9345's camera is the SoC camera-subsystem work in Linaro's tree (project log); mica's is USB (`MAINBOARD_HAS_CAMERA_VIA_USB`, `pp3300-ucam` rail), so
  likely plain UVC.

Follow-up (2026-10-21): the node-by-node comparison is [9345-dts-diff.md](9345-dts-diff.md), and the draft DTS built from it is in `dts/`.
