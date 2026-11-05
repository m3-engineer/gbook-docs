# The device tree, compared with the Nura port

Two public device trees describe mica, and both carry the same compatible string, `"google,mica", "qcom,x1e80100"`.
This page says how gbook's tree was built, what the other one does differently, and what the two authors would have
to settle before either goes upstream. The comparison was made on 2026-11-05, 2:37 PM EST by compiling both sources against the
same pinned kernel tree (torvalds `a804c57`) and diffing the compiled trees node by node; facts about the other
tree are structural (which nodes exist and are enabled, which properties are deleted), not quotations of its text.

## gbook's tree in one paragraph

[`x1e80100-google-mica.dts`](dts/x1e80100-google-mica.dts) starts from mainline's Dell XPS 13 9345 file, the closest
X1E80100 laptop, and changes every board-specific pin to what the stock ChromeOS tree says ([the DT README](dts/README.md),
"What changed from the 9345"). The stock tree is extracted from Google's public recovery image for this model, so each
change cites a line in it; a value with no stock counterpart is listed as unverified ("Unverified (check at first boot)").
The first-boot tree adds a `framebuffer` reservation at the stock splash address and is built as the board DTB plus
mainline's `x1-el2.dtso` overlay, followed by [`mica-el2.fixups`](dts/mica-el2.fixups), two property deletions that an
overlay cannot express ("First-boot additions"). Every enabled node binds since 2026-11-04
([the unbound-nodes note](docs/recon/unbound-2026-11-04.md)).

## The other tree

Anton Bambura's `x1e80100-bluey-mica.dts` (authored 2026-10-19, in his kernel tree for the postmarketOS-based
[Nura](https://wiki.nura.eco/wiki/Dell_XPS_Googlebook_(google-mica)) port; pmaports merge request 9856 "google-bluey: new
device", merged 2026-11-03) names the board `"Google Mica"` and includes the same two SoC files, `hamoa.dtsi` and
`hamoa-pmics.dtsi`. It compiles against `a804c57` once one binding header his tree carries is stubbed (a camera
orientation header not in the pinned tree), with three dtc warnings about thermal zones that use the PMIC's ADC as a
sensor without a sensor-cells property at this commit. Compiled, the two trees have 1,466 and 1,451 nodes; 1,383 and
1,366 of them are enabled.

## What each tree enables that the other does not

| Area | gbook only | Nura port only |
|---|---|---|
| Sound | the sound card, both SoundWire buses with two WSA8845 amplifiers each, the VA macro's microphone links, the two speaker-shutdown pin states, the microphone 3.3 V rail ([Sound on mica](sound.md)) | nothing; the port's wiki page lists audio as broken |
| USB | both USB MP (multiport) QMP PHYs enabled, as the 9345 has them (stock disables them; unverified) | the two eUSB reset pin states are named differently; a `usb-mp-reset-n` state |
| Video | the Iris video codec enabled | Iris disabled, with a note that it needs IOMMU work to start from EL2 |
| Input | touchpad and touchscreen pin states grouped per device, the TPM interrupt state | `gpio-keys` with a volume-up key on a PMIC GPIO, the PMIC's power-key `resin` node |
| Timers and watchdogs | the PMIC RTC, the SBSA generic watchdog | the APSS watchdog |
| SoC blocks | the crypto engine explicitly disabled (its driver is marked broken at this pin and the unbound node held two interconnect paths open) | the crypto engine, the two GPI DMA controllers and the PCIe SMMU enabled |
| Regulators | fixed regulators for the backlight, fingerprint MCU, touchpad, touchscreen, camera and microphones, named per consumer | the same rails under other names, plus a PWM power switch; eight RPMh regulators (seven LDOs and one SMPS) declared on the PMICs that gbook's tree does not declare |
| Reserved memory | the SoC file's regions kept, one `framebuffer` reservation added at the stock splash address | the SoC file's `reserved-memory` deleted as a whole and the needed regions redefined, with a comment that most of them overlap what depthcharge inserts at boot |

The 47 nodes only gbook enables and the 34 only the port enables are counted from the compiled trees; pin-state
subnodes make up most of both lists.

## Where the two trees make the same choice

- Both enter the kernel at EL2 and both drop the `iommus` property from the ADSP and CDSP remoteproc nodes. gbook
  does it with the fixups file after applying mainline's EL2 overlay; the port folds the overlay's changes into the
  source (its commit message says it includes the `x1-el2.dtso` changes except those two properties, which make the
  firmware fail to load). The reason gbook recorded on 2026-11-02: with `iommus` set the driver asks TrustZone for a
  resource table and mica's TrustZone answers with an error ([the fixups](dts/mica-el2.fixups)).
- Both load the ADSP and CDSP from the stock firmware. gbook names the stock split files (`adsp.mdt` and
  `adsp_dtb.mdt`) under a lowercase `qcom/x1e80100/google/mica/` path and ships hashes only
  ([`firmware.sha256`](kernel/firmware.sha256), [ADR 0005](docs/adr/0005-vendor-content-out-of-git.md)); the port names
  single `.mbn` files under a capitalised path and redistributes them in a firmware package. The two paths differ in
  case, so a rootfs built for one tree will not find the other's firmware without a symlink (inferred).
- Both keep the console on `uart21` and the Bluetooth UART on `uart14`, and both drive the ChromeOS EC over
  `spi13` with the keyboard matrix behind it.

## Where they differ in substance

| Topic | gbook | Nura port |
|---|---|---|
| CPU idle | `domain-idle-states` deleted from the twelve CPU power domains, so PSCI cpuidle does not load and the cores idle in WFI ([ADR 0009](docs/adr/0009-no-psci-cpuidle.md); why: [SCMI over the CPUCP mailbox](scmi-cpucp.md)) | the SoC file's idle states kept |
| SCMI | `arm,max-rx-timeout-ms = <1000>` on the SCMI node, marked unverified | the SoC file's default |
| Sound | described, booted, speakers and microphones working as of 2026-11-05 | absent |
| Thermal | the SoC file's zones | board thermal zones on the PMIC ADC (warnings at this kernel pin) |
| Model string | `"Dell XPS Googlebook"` | `"Google Mica"` |

Whether the port's machine shows the SCMI stall gbook measured is unknown here: its tree does not change the SCMI
timeout or the idle states, and no report either way was found (inferred from the tree alone).

## What this means for upstream

One compatible string can have only one board file in mainline. gbook holds every submission until its milestone M5
([ADR 0010](docs/adr/0010-milestones-status-upstream-hold.md)); the project's owner intends to write to the port's author
before then to coordinate a single `google,mica` tree and to offer the sound description and the SoundWire wake fix. Until
that conversation, this page is the diff. The DT README's "Before sending upstream" list (the binding entry, the block
order, the attribution header) applies to whichever tree goes first.
