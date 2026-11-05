# Milestones, version numbers and maturing the project

Researched 2026-11-04 from the kernel's own process documents at the pin (`~/.cache/gbook/linux-a804c57`,
`a804c5742bff`), the GitHub mirror of torvalds/linux, and project-owned pages: semver.org, calver.org,
keepachangelog.com, asahilinux.org, docs.nura.eco and wiki.nura.eco (postmarketOS), discourse.ubuntu.com (Canonical),
chromium.org and gitlab.com/Linaro. Raw pages are cached in `.firecrawl/milestones/` (gitignored). The device was not
touched. *Inference* marks what the source does not state; the Recommendation sections are this note's own proposals.

## Summary and recommendation

Decided 2026-11-04: the owner answered "all a" to section 5. The decisions are recorded in
[ADR 0010](../adr/0010-milestones-status-upstream-hold.md), [ADR 0011](../adr/0011-versions-and-releases.md) and the
[ADR 0007](../adr/0007-local-kernel-patches.md) update.

| # | Recommendation | Why, in one line |
|---|---|---|
| 1 | A **milestone ladder** M0 to M7 that slots rungs between the existing gates (table in [section 4](#4-proposed-milestone-ladder-for-gbook)) | Gate 2 to Gate 3 is a long stretch; Asahi, Nura and the 9345's own upstream commit all measure progress per feature |
| 2 | A **feature matrix** (`docs/status.md`): one row per feature, a state and an upstream column | Asahi's tables and Nura's device pages both do this; the README's "Resume here" paragraph does it as prose |
| 3 | **CalVer `YYYY.0M.0D[.MICRO]`** for a known-good image, as an annotated git tag, also visible in `uname -r` | SemVer needs a public API, which gbook does not have; the upstream kernel drives the releases |
| 4 | The **kernel's own `[PATCH vN]`** rules for anything sent upstream; a status word on every `kernel/patches/` header; never reuse a patch number | One scheme per audience: lists read `vN`, the repo reads dates |
| 5 | Keep holding upstream sends, but end the hold on a **checkable bar** (M5: binding + DTS pass the upstream checks) rather than on "mature" | The kernel docs favour posting early; the 9345 DTS landed with EC, speakers, mics and camera not working |

## 1. Milestones: how comparable projects define them

### Asahi Linux (Apple Silicon): a per-feature table with an upstream column

- **One table per SoC generation,** with rows for SoC blocks and per-device features, and columns per device
  ([M1 Series Feature Support](https://asahilinux.org/docs/platform/feature-support/m1/), read 2026-11-04;
  index at [Feature Support Overview](https://asahilinux.org/docs/platform/feature-support/overview/)).
- **Each cell says where the feature lives, not just whether it works** (same page, legend):
  - a kernel release, e.g. `6.0`: "incorporated upstream as of this release";
  - `linux-asahi (kernel release)`: stable, in Fedora Asahi Remix, "should be upstream by the release indicated";
  - `linux-asahi`: "(mostly) stable and available for use";
  - `WIP`: actively progressing, "not yet ready for wider testing";
  - `TBA`: no active work.
- **No dates are promised:** "If a feature is not ready, then there is no estimation on when it will be ready" (same
  page, intro).
- **Progress reports follow the upstream kernel:** the blog titles them "Progress Report: Linux 7.0", "7.1", "7.2"
  ([Asahi blog index](https://asahilinux.org/blog/), read 2026-11-04).
- **"Officially supported" means the installer offers it,** with listed exceptions. M3 support "has now been merged into
  the installer", "almost everything supported on the M1 and M2 series machines just works", with DCP, GPU and sleep
  listed as known limitations, at first behind the installer's Expert mode
  ([M2: Episode 1](https://asahilinux.org/2026/09/m2-episode-1/), 2026-09-06, read 2026-11-04).

### postmarketOS, now Nura: device categories with entry criteria

`wiki.postmarketos.org` now redirects to `wiki.nura.eco`, and the categorization page moved to docs.nura.eco (live read
2026-11-04). The categories ([Device Categorization](https://docs.nura.eco/pmaports/main/packaging/device-categorization.html),
read 2026-11-04) give the clearest written criteria for "this device reached level X":

| Category | Requirements (abridged from the page) |
|---|---|
| Testing | close-to-mainline kernel as new as the oldest supported LTS; compiled with LLVM; "Port and dependencies build"; "The device boots" |
| Community | install instructions on the wiki; close-to-mainline kernel; `pmbootstrap kconfig check --community`; automatic kernel upgrades work; maintainer joins release testing; kernel "upgraded through 3 kernel releases"; kernel not older than 6 months |
| Main | team endorsement; at least 5 maintainers; hardware CI in two locations for at least 3 devices; UEFI boot; generic kernel; a maintained working-features file |
| Downstream / Archived | vendor kernels as a step toward mainline; unmaintained or superseded ports |

- **Demotion is part of the scheme:** maintainers get two weeks (up to one more month on request) to meet the criteria
  again before a move down (same page, "Moving to a lower category").
- **Per-device feature matrix:** each device page lists features as Works / Broken / Untested. The Lenovo Yoga Slim 7x
  (x1e80100, category `testing`) lists, among others, Battery, Screen, Keyboard, Touchpad, 3D Acceleration, Audio,
  Wi-Fi and FDE as Works; Camera, Bluetooth and GPS as Broken; USB OTG as Untested
  ([Lenovo Yoga Slim 7x (lenovo-yoga-slim7x)](https://wiki.postmarketos.org/wiki/Lenovo_Yoga_Slim_7x_(lenovo-yoga-slim7x)),
  served from wiki.nura.eco, read 2026-11-04). No Nura page exists for the Dell XPS 13 9345 (live read 2026-11-04).

### The sibling laptop's own bar: the 9345 initial DTS in mainline

The commit that added the XPS 13 9345 board file (`f5b788d0e8cd`, "arm64: dts: qcom: Add support for X1-based Dell XPS
13 9345", authored 2024-10-03, applied by the qcom maintainer;
[commit](https://github.com/torvalds/linux/commit/f5b788d0e8cdaac7df6ec9a24926672965d87dfc), read 2026-11-04) states its
level in three lists:
- **Working:** touchpad, keyboard (after a suspend/resume, with an i2c-hid patch), touchscreen, eDP with brightness,
  NVMe, USB-C at USB 2/3 in one orientation, Wi-Fi, GPU/aDSP/cDSP firmware loading, lid switch, sleep/suspend.
- **Not working:** speakers, microphones, fingerprint reader, USB as DP/USB 3 (retimer), camera, EC over I2C.
- **Untested:** the higher-resolution panel.

Its binding went in as a separate patch, `1aa50217d7fd` "dt-bindings: arm: qcom: Add Dell XPS 13 9345" (GitHub commit
list for `qcom.yaml`, read 2026-11-04). Retimer support followed in a later commit (`bd2dbbb1f35a`, 2024-11-12). So an
x1e80100 laptop DTS was accepted upstream as "initial support" with audio, camera and EC missing.
At the pin, mainline carries 28 `x1*`/`hamoa*` board `.dts` files: laptops, reference and dev kits, and one desktop
(`ls arch/arm64/boot/dts/qcom/`).

### Distributions for the same SoC

- **Ubuntu Concept** (Canonical) lists x1e laptops in two groups, "Devices we have seen successful installations on"
  (the XPS 13 9345 among them) and "Currently not (yet) supported", with one Launchpad bug per device as its tracker
  ([Ubuntu Concept ♥️ Snapdragon X Elite](https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800),
  section "What works", read 2026-11-04).
- **Linaro's arm64-laptops kernel** names its integration branches by upstream base and series version, e.g.
  `arm64-laptops-v7.3-rc1-camss-v13`, `qcom-laptops-v6.18-rc4-camss-next`
  ([gitlab.com/Linaro/arm64-laptops/linux](https://gitlab.com/Linaro/arm64-laptops/linux), branch list, read
  2026-11-04). No first-party per-laptop status page was found there; the repository page carries the kernel README.

### ChromiumOS: status words for downstream kernel patches

There is no first-party "mainline on Chromebooks" status page that this search found. What ChromiumOS does publish is
a vocabulary for how far each downstream patch is from upstream
([Kernel Development](https://www.chromium.org/chromium-os/developer-library/guides/kernel/kernel-development/),
section "UPSTREAM, BACKPORT, FROMLIST, and you", read 2026-11-04):
- `UPSTREAM:` "exclusively for patches that have actually landed in Linus' tree";
- `BACKPORT:` same, with changes, which must be documented;
- `FROMGIT:` cherry-picks from a maintainer tree, naming tree and branch;
- `FROMLIST:` "sent to a public mailing list for review, but hasn't yet been merged", with a link;
- `CHROMIUM:` changes "which cannot be submitted upstream"; a rejected list patch kept anyway is `CHROMIUM: FROMLIST:`
  with the reason.

The older design page says the kernel is rebased onto new upstream releases "approximately every 3-6 months, and
approximately every other kernel versions"
([Chromium OS Kernel](https://www.chromium.org/chromium-os/chromiumos-design-docs/chromium-os-kernel/), "Upgrades",
read 2026-11-04; the page's examples are 2.6.32 and 3.x era, so treat it as dated).

### What the sources agree on (inference)

- A milestone is a **set of features at a stated location** (works locally, sent, in a release), not a date.
- Levels are defined by **checkable entry criteria** (Nura) or a **Working / Not working list** (the 9345 commit,
  Asahi's M3 post), and both allow named exceptions.
- **Upstream releases are the clock** for reports and rebases (Asahi reports, ChromiumOS rebases, Linaro branch names).

## 2. Version numbers

### What there is to version in gbook

| Object | Today | Changes when |
|---|---|---|
| The repo | 209 commits, no tags (`git tag`, 2026-11-04) | every unit of work |
| The boot image | `~/.cache/gbook/out/mica-usb.img`; its identity is the kernel banner (`release` + `#<n>` UTS build number, `scripts/image_uts.sh`) | each `package-image.sh` |
| The kernel base | torvalds `a804c57` (ADR 0004) | a re-pin |
| Local patches | `kernel/patches/NNNN-*.patch`, header says source and upstream state ([ADR 0007](../adr/0007-local-kernel-patches.md)) | per patch |
| The DTS | `dts/x1e80100-google-mica.dts`, history in git | per commit |
| A boot | attempt ID `YYYY-MM-DD-N` in gitignored `dumps/firstboot/attempts.tsv` (`scripts/attempt.sh`) | every boot |
| An upstream series | none sent yet | per posting |

Facts about the base (live reads 2026-11-04): the pin's `Makefile` reads `7.3.0` with an empty `EXTRAVERSION`; the
GitHub compare API puts `a804c5742bff` 1703 commits after `v7.3` (tagged 2026-10-18 7:14 PM ET [23:14 UTC]) and before
`v7.4-rc1` (tagged 2026-11-01 4:26 PM ET [21:26 UTC]); the pin was committed 2026-10-21 2:04 AM ET [06:04 UTC]. So
the pin is a 7.4 merge-window commit. No `kernel/*.config` sets `CONFIG_LOCALVERSION` (grep, 2026-11-04).

Two local patch numbers have been reused: `0008` named a GENI I2C timing patch (commit `16a2828`) and now names the
PCIe GDSC patch (`5272658`), and `0009` named the IRQ-to-CPU-1 diagnostic ([ADR 0009](../adr/0009-no-psci-cpuidle.md), "Decision":
deleted) and now names the PCIe PHY GDSC patch (running log, 2026-11-04 rows).

### The schemes

- **SemVer 2.0.0** ([semver.org/spec/v2.0.0](https://semver.org/spec/v2.0.0.html), read 2026-11-04):
  - item 1: "Software using Semantic Versioning MUST declare a public API";
  - item 4: "Major version zero (0.y.z) is for initial development. Anything MAY change at any time";
  - item 10: build metadata after `+` (e.g. `1.0.0-beta+exp.sha.5114f85`) is ignored for precedence;
  - FAQ "How do I know when to release 1.0.0?": when it is used in production or users depend on a stable API;
  - FAQ "Is v1.2.3 a semantic version?": no; `v1.2.3` is a tag name, the version is `1.2.3`.
- **CalVer** ([calver.org](https://calver.org/), read 2026-11-04):
  - conventions `YYYY`, `0M`, `0D`, `MICRO`; multiple releases a day append a micro segment, `2026.9.11.1`
    ("Multiple releases per day?");
  - "When to use CalVer?": a large or changing scope, or "Do other external changes drive new project releases?";
  - "CalVer deliberately does not attempt to communicate breaking changes … There is no substitute for a changelog";
  - the same section opens "If third parties use your project, then use a serious version."
- **Kernel patch series** (`Documentation/process/submitting-patches.rst` at the pin,
  [GitHub](https://github.com/torvalds/linux/blob/a804c5742bff/Documentation/process/submitting-patches.rst)):
  - "The canonical patch format", "Subject Line": "v1, v2, v3" for versions sent in response to comments, "RFC" for a
    request for comments, `[PATCH v2 M/N]`;
  - "Commentary": the per-version changelog goes below the `---` line, with links to earlier versions on lore;
  - "Describe your changes": each version must be self-contained, "Don't just say that this is version N";
  - "Don't get discouraged - or impatient": `[PATCH Vx RESEND]` only for an unmodified resend;
  - "Providing base tree information": `git format-patch --base`, and the base "in an official maintainer/mainline
    tree";
  - "Tooling": b4 automates dependency tracking, checkpatch and sending.
- **Git tags** (`git-tag(1)`, local man page, read 2026-11-04): "Annotated tags are meant for release while
  lightweight tags are meant for private or temporary object labels"; `git describe` ignores lightweight tags by
  default.
- **Keep a Changelog 1.1.0** ([keepachangelog.com/en/1.1.0](https://keepachangelog.com/en/1.1.0/), read 2026-11-04):
  for humans; an entry per version, newest first, with its date; `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`,
  `Security`; an `Unreleased` section on top; "Using commit log diffs as changelogs is a bad idea".
- **Making it visible on the device:** `CONFIG_LOCALVERSION` appends a string to the kernel release, after "any files
  with a filename matching localversion* in your object and source tree"; the total is at most 64 characters
  (`init/Kconfig` at the pin, `config LOCALVERSION`).

### Recommendation

- **Do not use SemVer for the repo or the image.** gbook declares no public API (item 1), and the thing others will
  depend on, the `google,mica` binding and DTS, is versioned by upstream once merged (inference).
- **Use CalVer `YYYY.0M.0D[.MICRO]` for a released image,** tagged as an annotated tag `v2026.11.04` (`v` as the tag
  prefix, per the SemVer FAQ's convention). A release is an image you would hand to someone else: one that passed a
  stated number of cold boots, shown by `attempt.sh tally` (CLAUDE.md docs conventions). The upstream base and the
  milestone are the reasons a new one is cut, which is CalVer's "external changes drive releases" case.
- **One tag message carries the links.** It names the kernel base (`a804c57`, "v7.3 + 1703, 7.4 merge window"), the
  patch list with status words, the milestone, and the attempt IDs that proved it.
- **Version vs attempt ID:** a version names an image, and an attempt ID names one boot of an image. Several attempts
  boot one version; an attempt of an untagged image stays an experiment. Add the version to the attempt's row when
  `attempt.sh new` sees a tagged commit (inference: the column does not exist yet).
- **Show the version on the device:** have `build-kernel.sh` write a `localversion-gbook` file into the build directory
  (e.g. `-gbook2026.11.04`, or `-gbook<git describe>` for an untagged build), so `uname -r` and the netlog's
  `Linux version` line name the gbook state. The kernel tree's own `-dirty` suffix stays as it is.
- **Upstream series use the kernel's scheme only:** `[PATCH RFC]`, then `[PATCH v2]` and so on, changelog below
  `---`, `--base`, b4 if adopted. The repo version never appears in a patch subject.
- **Local patches:** add one status line to each header, using the ChromiumOS words plus one of ours: `LOCAL`
  (gbook only, like `CHROMIUM:`), `FROMLIST <lore Message-ID>`, `FROMGIT <tree branch>`, `UPSTREAM <tag>`. Today that
  reads 0001 LOCAL, 0002-0006 and 0008 FROMLIST, 0007 Omarchy's fix-up (LOCAL, third-party), 0009 LOCAL (inference
  from the headers and ADR 0007). Numbers only grow: a deleted patch's number is retired.
- **Changelog:** the running log stays the history. Start `CHANGELOG.md` (Keep a Changelog) only when a tagged image
  first leaves the build host; until then the annotated tag message is the release note.

## 3. Maturing the project

### When to start upstreaming: what the kernel docs say

- **Post early.** "posting your plans during the early stages can only be helpful"
  (`Documentation/process/3.Early-stage.rst`, "When to post?"). For complex work "there is a lot to be gained by getting
  feedback from the community before the work is complete", and code not ready for inclusion should say so and list
  the known problems (`5.Posting.rst`, "When to post").
- **The merge window** lasts about two weeks; afterwards only fixes go in for six to ten weeks until the release
  (`2.Process.rst`, "The big picture"). New board files reach the merge window through the platform tree: for qcom the
  `T:` entry is `git.kernel.org/pub/scm/linux/kernel/git/qcom/linux.git` with maintainers Bjorn Andersson and Konrad
  Dybcio, list `linux-arm-msm@vger.kernel.org`, IRC `#linux-msm` on OFTC (`MAINTAINERS` at the pin, "ARM/QUALCOMM
  SUPPORT"). Patches should be prepared against that tree, not mainline (`submitting-patches.rst`, "Obtain a current
  source tree").
- **Board DTS rules** (`maintainer-soc.rst`, "Validating Devicetree Files"; `maintainer-soc-clean-dts.rst`;
  `maintainer-devicetree.rst`):
  - `make dtbs_check` adds no new warnings;
  - no `scripts/dtc/dt-check-style` warnings in relaxed mode, and most strict-mode ones addressed (the script exists at
    the pin);
  - DTS go through the SoC platform tree, separate from driver patches.
- **Binding rules** (`Documentation/devicetree/bindings/submitting-patches.rst`, items 1, 5, 6, 7):
  - the binding is a separate patch, `dt-bindings: <dir>: …`;
  - it comes before its users in the series;
  - every compatible in a board DTS "must be previously documented", which for mica means a `google,mica` entry in
    `arm/qcom.yaml`;
  - DTS patches go last or in their own series.

  `qcom.yaml` already describes depthcharge boards ("many devices … use the open source depthcharge bootloader") with
  `google,<board>[-revN][-skuN]` entries such as `google,coachz-rev1`. The match order they rely on is documented in
  `Documentation/arch/arm/google/chromebook-boot-flow.rst`; it falls back to plain `google,$(BOARD)`, which fits
  [ADR 0004](../adr/0004-device-tree-from-9345.md)'s `google,mica`.
- **AI-assisted work** (`coding-assistants.rst`, `generated-content.rst`):
  - "AI agents MUST NOT add Signed-off-by tags. Only humans can legally certify the Developer Certificate of Origin";
  - the human submitter reviews all AI-generated code and takes responsibility;
  - an AI assistant "must never send anything itself";
  - contributions should be transparent about which tools were used, on which parts, and how it was tested.

  207 of gbook's 210 commits carry a `Co-Authored-By: Claude` trailer (`git log`, 2026-11-04), so this is a hard
  prerequisite for any send.
- **DT ABI:** "a stable binding means that a newer kernel will not break on an older device tree"
  (`Documentation/devicetree/bindings/ABI.rst`). *Inference:* once `google,mica` is upstream, changes to it carry that
  constraint, which is one reason to post the binding only when the board's compatible scheme is settled.

### What blocks a clean upstream DTS today (inference, from repo files)

- **Unverified items:** `arm,max-rx-timeout-ms = <1000>` is marked unverified (README "Resume here"), and other
  unverified items are listed in [`dts/README.md`](../../dts/README.md).
- **No idle states:** [ADR 0009](../adr/0009-no-psci-cpuidle.md) deletes `domain-idle-states` from every CPU domain.
  Upstream may want the SoC problem fixed or explained first; the unsent
  stall report is the natural RFC for that.
- **Base tree:** the pin is a merge-window commit; a series has to be rebased onto the qcom tree.
- **Kernel-side support:** the panel entry (0001) needs the full panel name, and the GMU and GDSC patches are other
  people's series in flight.

### Release cadence, roadmap, CI

- **Cadence (recommendation):** event-driven, not calendar-driven. Cut a tagged image when a milestone is reached or
  the pin moves. Re-pin at most once per mainline release, onto a release tag such as `v7.4`; ChromiumOS rebases every
  other release, and Asahi reports once per release.
- **Roadmap:** the ladder in section 4, kept in the README's phase table, with a `.scratch/<milestone>/map.md` per
  active milestone. The repo already uses wayfinder maps (`.scratch/phase-2-first-boot/map.md`,
  issue tracker).
- **Status:** `docs/status.md` in the Asahi/Nura form. Rows: feature; state (works / partial / broken / untested); where
  it works (mainline at pin / local patch NNNN / board DTS only); upstream (no / sent vN / in 7.x); evidence (recon
  note). It replaces the feature prose in "Resume here".
- **CI:** `scripts/check.sh` through lefthook already runs on every commit. Add upstream's own
  checks when M5 starts: `make dtbs_check`, `dt-check-style`, `checkpatch.pl` on exported patches. Server-side CI on
  the the private remote and hardware CI (a Nura "main" requirement) are out of proportion for one owner and one device.
- **Outside contact before upstream:** the plan already lists joining `#aarch64-laptops`
  (project log, Phase 1). Posting the recon there is "posting your plans" at no ABI cost.

## 4. Proposed milestone ladder for gbook

*Inference throughout:* rung names, criteria and states are proposals. "Borrowed from" names the outside criterion each
rung copies. The state column is from the README's "Resume here" and the recon notes.

| M | Name | Phase / gate | Done when | Borrowed from | State 2026-11-04 |
|---|---|---|---|---|---|
| M0 | Way back to stock | Phase 1, Gate 1 | recovery media reach the recovery screen; relock tested ([ADR 0001](../adr/0001-recovery-gates-unlock.md)) | (gbook) | passed 2026-11-02 |
| M1 | First light | Phase 2, Gate 2 | our `Linux version` line on the AP console, panel or readback ([CONTEXT.md](../../CONTEXT.md)) | Nura testing: "The device boots" | passed 2026-11-02 |
| M2 | Board on the console | Phase 3, rung 1 | every enabled DT node binds; USB, PCIe, Wi-Fi, display, GPU probe, EC keyboard, touchpad, TPM, suspend round trip; N clean cold boots by `tally` | the 9345 commit's Working list | nearly: all of these since 2026-11-04 ([unbound](../recon/unbound-2026-11-04.md), [suspend](../recon/suspend-2026-11-04.md)); touchscreen parked ([touch-tpm](../recon/touch-tpm-2026-11-03.md)) |
| M3 | Userspace from USB | Phase 3, rung 2 | a rootfs from USB with Mesa on the GPU, networked Wi-Fi, audio state known; first tagged image | Nura device page rows (3D, Wi-Fi, Audio, Battery) | not started |
| M4 | Daily-drivable | Phase 3, Gate 3 | install on internal storage (spare SSD, [ADR 0002](../adr/0002-experiment-on-spare-ssd.md)), dual-boot or documented return to stock | README Gate 3; Asahi "official": the installer offers it | not started |
| M5 | Upstream-ready | Phase 4 entry | binding and DTS on the qcom tree pass `dt_binding_check`, `dtbs_check` (no new warnings), `dt-check-style` relaxed, checkpatch; Working / Not working list written; every local patch labelled; a human signs off | maintainer-soc, bindings/submitting-patches, coding-assistants | not started; can run in parallel with M3/M4 |
| M6 | Upstream | Phase 4, Gate 4 | `google,mica` binding and DTS applied to the qcom tree, then in a mainline release; firmware question settled | README Gate 4; Asahi's "kernel release" cell | not started |
| M7 | In a distribution (optional) | after Phase 4 | a Nura `testing` device package, or a device entry in Ubuntu Concept | Nura categories; Ubuntu Concept list | not started |

## 5. Open questions for the owner

Reply in the usual form ("1a 2 ok"); each has a recommended answer.

1. **The ladder.** a) adopt M0-M7 and add the rungs to the README phase table; b) keep phases and gates only.
   *Recommended: a.*
2. **Version scheme for images.** a) CalVer `YYYY.0M.0D[.MICRO]` annotated tags for released images; b) SemVer
   `0.y.z`, one minor per milestone; c) no versions until upstream. *Recommended: a.*
3. **What counts as a release.** a) an image that passed 3 clean cold boots by `tally` and is the one you would hand
   on; b) every image that reaches a new milestone, regardless of boot count. *Recommended: a.*
4. **Version on the device.** a) `build-kernel.sh` writes a `localversion-gbook` file, so `uname -r` names the gbook
   state; b) leave the kernel release as is. *Recommended: a.*
5. **Patch headers.** a) add a status line (`LOCAL` / `FROMLIST` / `FROMGIT` / `UPSTREAM`) to every
   `kernel/patches/` header and retire deleted numbers; b) leave the free-text headers. *Recommended: a*, as an ADR 0007
   update.
6. **Changelog.** a) the annotated tag message is the release note until an image leaves the build host, then `CHANGELOG.md`
   (Keep a Changelog); b) start `CHANGELOG.md` now. *Recommended: a.*
7. **When the upstream hold ends.** a) hold until M5's checks pass, then send the binding and DTS as `[PATCH RFC]`;
   b) post an RFC of the binding and current DTS after M2; c) hold until M4. *Recommended: a*, plus the IRC post from
   the Phase 1 list now, which costs no ABI.
8. **Re-pin policy.** a) re-pin onto the next mainline release tag (`v7.4`) after M3, and before M5 in any case;
   b) re-pin only when a needed fix lands. *Recommended: a.*
9. **Status matrix.** a) a new `docs/status.md`, with "Resume here" pointing to it; b) a table in the README.
   *Recommended: a.*

## Sources

All read 2026-11-04. Kernel documents at the pin `a804c5742bff` (local tree `~/.cache/gbook/linux-a804c57`, mirrored at
`https://github.com/torvalds/linux/tree/a804c5742bff`).

- Kernel: `Documentation/process/submitting-patches.rst` (sections named inline), `2.Process.rst`, `3.Early-stage.rst`,
  `5.Posting.rst`, `maintainer-soc.rst`, `maintainer-soc-clean-dts.rst`, `maintainer-devicetree.rst`,
  `coding-assistants.rst`, `generated-content.rst`; `Documentation/devicetree/bindings/submitting-patches.rst`,
  `bindings/ABI.rst`, `bindings/arm/qcom.yaml`; `Documentation/arch/arm/google/chromebook-boot-flow.rst`;
  `MAINTAINERS` ("ARM/QUALCOMM SUPPORT"); `init/Kconfig` (`LOCALVERSION`); `Makefile`.
- torvalds/linux on GitHub: [f5b788d0e8cd](https://github.com/torvalds/linux/commit/f5b788d0e8cdaac7df6ec9a24926672965d87dfc)
  (9345 DTS), commit list for `qcom.yaml` (`1aa50217d7fd`) and the 9345 DTS (`bd2dbbb1f35a`); tags `v7.3`, `v7.4-rc1`
  and compare `v7.3...a804c5742bff` via `gh api`.
- SemVer 2.0.0: https://semver.org/spec/v2.0.0.html
- CalVer: https://calver.org/
- Keep a Changelog 1.1.0: https://keepachangelog.com/en/1.1.0/
- `git-tag(1)`, DESCRIPTION (local man page).
- Asahi Linux: https://asahilinux.org/docs/platform/feature-support/overview/ ,
  https://asahilinux.org/docs/platform/feature-support/m1/ , https://asahilinux.org/blog/ ,
  https://asahilinux.org/2026/09/m2-episode-1/
- Nura (postmarketOS): https://docs.nura.eco/pmaports/main/packaging/device-categorization.html ,
  https://wiki.postmarketos.org/wiki/Lenovo_Yoga_Slim_7x_(lenovo-yoga-slim7x) (served from wiki.nura.eco)
- Ubuntu Concept: https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800
- Linaro: https://gitlab.com/Linaro/arm64-laptops/linux
- ChromiumOS: https://www.chromium.org/chromium-os/developer-library/guides/kernel/kernel-development/ ,
  https://www.chromium.org/chromium-os/chromiumos-design-docs/chromium-os-kernel/
