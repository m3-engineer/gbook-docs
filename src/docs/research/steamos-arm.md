# SteamOS on ARM: what Valve has published for the Steam Frame, and what gbook can take from it

Researched 2026-11-05 (written 10:41 AM EST [15:41 UTC]) on the build host, task #30 (owner's idea 2026-11-05). First-party sources only:
Valve's GitHub organisation and gitlab.steamos.cloud (through their APIs), Valve's package servers (directory listings
and the pacman databases, plus ten packages downloaded into the scratchpad and read, never installed), the
Steam store, Steamworks partner documentation and Steam Support pages, the Steam news API, Valve-authored commits
reachable through GitHub's `torvalds/linux` commit endpoint, Mesa and FEX upstream, and the kernel tree at gbook's pin
(`~/.cache/gbook/linux-a804c57`). The Googlebook was not touched. Nothing was installed. *Inference* marks what no
source states. Package versions are as listed on 2026-11-05 and will move. Proprietary packages (licence field
`Proprietary`) are described; only identifying strings (menu entries, messages, a comment fragment, USB IDs) are
quoted from them, never code. One configuration file carries a shared CI credential, which is not copied.

Context: gbook builds its rootfs with `scripts/build-rootfs.sh` (Debian sid, snapshot-pinned, mmdebstrap in a rootless
podman container, [ADR 0012](../adr/0012-m3-rootfs-debian-sid.md)) and its boot image with `scripts/package-image.sh`
(FIT image on the ChromeOS KERN-A partition, dev-key signed, [ADR 0003](../adr/0003-first-boot-chromeos-kernel-partition.md));
the kernel is torvalds `a804c57` plus `kernel/patches/0001-0011` ([ADR 0007](../adr/0007-local-kernel-patches.md)) and
the `kernel/*.config` fragments; firmware is staged by `scripts/stage-firmware.sh` (stock `modem_a` plus distro
packages, hashes in `kernel/firmware.sha256`). Milestone M4 needs a documented return to stock
([ADR 0010](../adr/0010-milestones-status-upstream-hold.md)).

## Answer in short

1. **Valve has not published an ARM SteamOS source tree or image-build pipeline.** What is public is the Steam Frame's
   *package repositories* (Arch Linux rebuilt for aarch64 plus Valve's own `deckard-*` and `steamos-*` packages), a
   *repair image* and a *QDL flash package* (about 4 GB each), the mainline `sm8650-valve-deckard.dts`, Lepton (the
   Android compatibility tool), an Arch aarch64 "preview" package-source mirror, and developer documentation.
2. **The Frame's kernel is Linux 7.2 plus 1,178 commits** (a 6.18 branch carries 1,215) from a private GitLab tree
   whose commits resolve through GitHub. None of gbook's eleven patches is in it; Valve touches the same SoundWire,
   WSA884x and GMU code with different, mostly `HACK:`-prefixed changes, and carries no x1e80100, SCMI or panel-edp work.
3. **The OS layout is Steam Deck's, ported:** RAUC A/B raw root slots named by "partsets", read-only root, `/etc`
   overlay on a per-slot `var`, shared `home`, casync/desync delta updates, U-Boot with a boot menu, `splctl` for the
   boot-firmware slot. The best gbook candidates are the recovery matrix (section 5), a `ramoops` region, the ath12k
   IOMMU and IRQ workarounds, and the WirePlumber card rules (section 6).

## What is public

| Where | What | Pin read 2026-11-05 | Licence |
|---|---|---|---|
| [github.com/ValveSoftware](https://github.com/ValveSoftware) (55 repos listed by the API) | Nothing ARM. `steamos_kernel` ("SteamOS kernel branches", default branch `brewmaster-4.11`, last push 2023-05-22), `steamos_mesa` (last push 2018-10-13), `linux` (Debian kernel-packaging fork, 2018-01-11), `SteamOS` (issue tracker), `gamescope` (fork) | repo list | `NOASSERTION` on the kernel repos |
| [gitlab.steamos.cloud](https://gitlab.steamos.cloud/explore/projects) (46 public projects listed by `/api/v4/projects`) | `holo/holo-core-aarch64-preview`, `frame-public/lepton`, `frame-public/frame-developer-tools`, `frame-public/android-vulkan-headers`, two Waydroid forks, `SteamHardware/SteamFrame`, `holo/steamos-manager`, `holo/fakemachine`, `devkit/steamos-devkit`, the Steam Runtime (`steamrt/*`) and Proton SDK groups | see rows below | per project |
| `holo/holo-core-aarch64-preview` (project 1471) | Read-only mirror of the package *sources* (PKGBUILDs) behind the "preview Arch Linux aarch64 port", built by Collabora from Arch's packaging state of 2025-11-18 (`97c0a0b4`), with aarch64 build fixes and licence fixes (Arch RFC 40). Binary repo at `holo-packages.steamos.cloud/holo-core-aarch64-preview/mash-20251118{,.2,.3}/{core,extra}/os/aarch64/`, a `system.rootfs.zst` (384,971,555 bytes, not downloaded), `pacman.conf` with `SigLevel = Optional`. Its `linux` is Arch's `6.17.8.arch1-1` PKGBUILD, but the `config` in that tree is the x86 one (`# Linux/x86 6.17.8-arch1 Kernel Configuration`); its `mesa 1:25.2.7-1` enables `freedreno` in both `gallium-drivers` and `vulkan-drivers`. "Technology preview ... not intended for use as a permanent operating system" (readme) | `main` = `67f0d559` (2026-06-10) | no licence file; the PKGBUILDs carry Arch's |
| `frame-public/lepton` (project 1518) | Lepton, "a tool for use with the Steam client which allows games which are exclusive to Android to run on the Linux operating system": a Waydroid/Anbox/Halium-derived Android container image (`image/`) and a non-root compat tool (`compat_tool/`) that mounts the host's Mesa and Zink into the container. Built in a podman container (`image/do_build.sh`) | `main` = `5964972a` (2026-11-03), tag `v3.0.10` | MIT (tool), GPL-3.0 (image) per `LICENSE.md` |
| `frame-public/frame-developer-tools` (project 1324) | perfetto, gpuvis and gfxreconstruct wrappers, gamescope helpers, and `pacman/deckard-pacman-src`, a 50-line script that maps a package's repo URL to its PKGBUILD location: `holo-packages.steamos.cloud/archlinux-deckard/archlinux//main/{core,extra}/os/aarch64` → `gitlab.steamos.cloud/potato/mash/monorepo`, `.../core-bootstrap/...` → `potato/mash/bootstrap`, `archlinux-deckard/bootstraps/` → `potato/smash/holo`, `archlinux-deckard-hotfixes/` → `deckard/deckardos/holo`. Every one of those GitLab paths answers 404 unauthenticated | `main` = `16d1942e` (2026-09-02) | none stated |
| `SteamHardware/SteamFrame` (project 1521) | CAD of the core module, head strap and controllers, expansion-port documents, two USB-hub reference designs | `master` = `bdbb41ba` (2026-10-13) | CC-BY-NC-SA-4.0 (`license.txt`) |
| `holo/steamos-manager` (project 1288) | The D-Bus daemon behind Steam's system settings; `data/devices/steam-frame.toml` identifies the Frame by `dt.compatible = "qcom,sm8650"` and `board-info/board_revision`, names it `device = "steam_frame"`, `variant = "Deckard"`, and sets GPU devfreq limits (`/sys/devices/platform/soc@0/3d00000.gpu/devfreq/3d00000.gpu`, manual minimum 500, powersave maximum 629) and per-profile cpufreq caps for policies 0, 2, 5 and 7 (Performance 2,265,600 / 3,148,800 / 2,956,800 / 3,052,800 kHz) | `main` = `a3b20137` (2026-10-24) | MIT |
| `holo/fakemachine` (project 1315) | A fork of Collabora's fakemachine (the VM runner used by debos); last commit 2021-05-31 | `master` = `74dd229b` | Apache-2.0 |
| `steamdeck-packages.steamos.cloud/archlinux-mirror/` | The Steam Deck and Steam Machine repos (`jupiter-*`, `holo-*`, 217 folders). **x86_64 only**: every `*/os/` folder lists `x86_64/` alone; `holo-main/os/aarch64/`, `jupiter-main/os/aarch64/` and guessed `frame-*` names answer 404 | listing | |
| `holo-packages.steamos.cloud/archlinux-deckard/archlinux/main/{core,extra}/os/aarch64/` | **The Frame's base repos**: Arch Linux rebuilt for aarch64 by "GitLab CI Package Builder <ci-package-builder-1@steamos.cloud>" (`core.db`). core: 272 packages, extra: 4,114, dated 2025-12-01 to 2026-10-30, each with a `.sig`. `archlinux-deckard/archlinux/` also lists snapshot folders `mash-20240428` … `mash-20260528` (some `.pvt`), `archives/`, `builds/`, `dev/`, `pipeline/`. The server root answers 401 | listing and `core.db.tar.xz` | Arch's per package |
| `holo-packages.steamos.cloud/archlinux-deckard-hotfixes/` | **Valve's own Frame packages**: 1,978 package files, 497 non-debug package bases, dated 2025-08-06 to 2026-11-04, plus 160 subfolders (`goldmaster/`, `mr-1020/` … `mr-1133/`, one pacman repo per merge request) and `create_new_release_from_main.sh`/`create_staging.sh`. Database `deckard-arch-hotfixes.db.tar.xz`. Package URLs name private GitLab projects under `deckard/deckardos/` (all 404) | listing, `.db` and `.files` | per package (see below) |
| `steamdeck-images.steamos.cloud/recovery/` | `steamframe-oobe-repair-20260922.5153644-0.3.0.img.bz2` (4,068,109,407 bytes, Last-Modified 2026-09-22 22:57 UTC) and `.zip`; `steamframe-oobe-repair-qdl-20260922.5153644-0.3.0.tar.gz` (4,100,462,821 bytes) and `.zip`; the store's "download SteamOS for Frame" link (`store.steampowered.com/steamos/download/?ver=steamframe`) points at `steamframe-repair-latest.img.bz2`, which redirects to the first file. **Not downloaded** (see "Not found") | `HEAD` | not stated |
| torvalds `arch/arm64/boot/dts/qcom/sm8650-valve-deckard.dts` | "Add initial DeviceTree for the Valve "Steam Frame" codename Deckard ... based on the Qualcomm Snapdragon 8 Gen 3 SoC (SM8650) ... The bootloader starts Linux in EL2, thus a bunch of EL1 & DSP related nodes needs to be removed" (commit message). Author Neil Armstrong (Linaro), `Copyright (c) 2026, Valve Software`; binding `abbbaa99ac66`; merged through `qcom-arm64-for-7.4-2` and `soc-dt-7.4` (`7b9a0e857b42`, 2026-10-22). **Not in gbook's pin**: `compare a804c5742bff...f905cb6e600a` says `diverged`, 135 commits ahead. Follow-ups on linux-arm-msm patchwork: `chassis-type` (2026-09-24), watchdog (2026-10-02), camera sensors v2 (Vladimir Zapolskiy, 2026-10-02) | `f905cb6e600a` (2026-09-23) | BSD-3-Clause |
| Steamworks partner docs, `partner.steamgames.com/doc/steamhardware/steamframe{,/setup,/debugging,/loadgames,/compat,/engines/custom}` | "The Steam Frame runs on SteamOS, which is a gaming focused Linux distribution based on Arch"; Developer Mode gives ssh, adb and RDP (user `steamos`, XRDP Xorg session); "By default the filesystem is read-only ... `sudo steamos-readonly disable`"; `sudo pacman -S`; `coredumpctl`; runtimes offered by the devkit client: Android (APK through Lepton), "Steam Linux Runtime 3.0 ARM64 (Sniper)" for native arm64 builds, "Steam Play (Proton)" for Windows builds; custom engines should target "Android 10 or Linux Arm64"; System Update Channel `Beta` | read 2026-11-05 | Valve |
| Steam Support: [SteamOS Recovery and Troubleshooting](https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3), [SteamOS Installation and Repair](https://help.steampowered.com/en/faqs/view/65B4-2AA3-5F37-4227), [Steam Frame guide](https://help.steampowered.com/faqs/view/2668-0B6E-79E0-A85B), [LEDs and button chords](https://help.steampowered.com/faqs/view/4F01-E85C-4977-EA0E) | Rollback and USB-repair steps for the Frame (section 5); "Purple, solid: Steam Frame is in bootloader" | read 2026-11-05 | Valve |
| Steam news for app 4165890 (`api.steampowered.com/ISteamNews/GetNewsForApp/v2/`) | "SteamOS 0.3.0 for Steam Frame" (2026-09-17), 0.4 (2026-10-08), "0.5.7 Beta" (2026-11-04). The version line is `0.x (for Steam Frame)`, separate from the Deck's 3.x; the store page lists "SteamOS 3". No kernel versions in any note | read 2026-11-05 | Valve |
| Valve's kernel tree, through GitHub | `linux-72-deckard 7.2.0+g344f27110f05-1` and `linux-618-deckard 6.18.0+gee93c0d9394b-1` name `gitlab.steamos.cloud/deckard/deckardos/linux-valve` (404). Both SHAs resolve at `api.github.com/repos/torvalds/linux/commits/<sha>` because GitHub serves objects from the whole fork network; `search/commits?q=hash:` finds no repository, so there is no named public branch (section 3) | `344f27110f05` (2026-11-03), `ee93c0d9394b` (2026-10-23) | GPL-2.0-only |
| FEX | [FEX-Emu/FEX](https://github.com/FEX-Emu/FEX) (MIT, release `FEX-2610` 2026-10-07; the GitHub login `Plagman`, `git@plagman.net`, has 44 commits); [fex-emu.com "The scourge of x86 emulation"](https://fex-emu.com/Scourge-of-emulation/) names "the platform we're testing on, which is of course the Valve Steam Frame", the kernel patch [bylaws/linux `7ae989a43ae7`](https://github.com/bylaws/linux/commit/7ae989a43ae7e3cb8007ac21c28dacc24c9d8320) (Billy Laws, 2025-08-06, `arch/arm64/kernel/unaligned_atomic.c`) and the Turnip MR [!41323](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/41323) (Ryan Houdek, merged 2026-05-08) | read 2026-11-05 | MIT / GPL-2.0 |
| Mesa upstream (GitLab API) | Adreno 750 (the Frame's GPU) merge requests that name Valve content: [!44840](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44840) "tu: Set SP_CHICKEN_BITS_2 bit 30 on A750 for HL: Alyx" (Dhruv Mark Collins, Igalia, merged 2026-10-06), [!44348](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44348) SUBPASS_FENCE on a7xx+ (Connor Abbott, 2026-09-14), [!45615](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/45615) a7xx gen1/gen2 quirk (Danylo Piliaiev, Igalia, 2026-10-27). The MRs do not state who funds the work | read 2026-11-05 | MIT |

## 1. Repos, packages and trees, with licences and pins

The table above pins each source. Licences of the Frame packages, from the `desc` entries in `deckard-arch-hotfixes.db`
(read 2026-11-05):

| Package (newest in the hotfixes repo) | What | Licence field | Source URL in the package |
|---|---|---|---|
| `linux-72-deckard 7.2.0+g344f27110f05-1` (built 2026-11-04 18:15 UTC); `linux-618-deckard 6.18.0+gee93c0d9394b-1` | the kernel, `Image` + modules + every `qcom/*.dtb` | GPL-2.0-only | `deckard/deckardos/linux-valve` (404) |
| `linux-firmware-deckard 20261023.1+git594f649d-1` | Valve's firmware set (section 4) | `custom` | `deckard/deckardos/linux-firmware` (404) |
| `linux-firmware-qcom 20260519-1` (core) | Arch's split of kernel.org linux-firmware | LicenseRef-WHENCE | kernel.org |
| `deckard-boot-firmware 20261021.1.uboot20261019.1-3`, `deckard-boot-luns`, `deckard-boot-images`, `deckard-hw-support 20261103.1-1` | U-Boot build, Qualcomm boot firmware, LUN GPT images, boot splash, hardware-support scripts and initramfs hooks | **Proprietary** (`deckard-boot-images` also OFL-1.1) | `deckard/deckardos/u-boot`, `.../deckard-hw-support` (404) |
| `deckard-uboot-splctl 20260128.3-6` | "Deckard second-stage bootloader controller" (`/usr/bin/splctl`) | GPL-2.0+ | `deckard/deckardos/deckard-uboot-splctl` (404) |
| `steamos-efi 20260122.2-3` | "Stage 1 bootloader for SteamOS 3+", here an aarch64 build (`/usr/lib/steamos-efi/aarch64-efi/steamcl.efi`) | GPL2 | `deckard/deckardos/steamos-efi` (404) |
| `steamos-customizations-deckard 20261002.1-4` | "SteamOS customizations (Deckard fork)": RAUC and atomupd configuration, partsets, mounts, reset tools, udev rules (section 2, 5) | LGPLv2+ | `repo.steampowered.com` |
| `deckard-atomupd-config 20250820.1-1`, `steamos-atomupd-client 0.20260331.1-4`, `atomupd-daemon 0.20260810.0-4`, `steamos-reset 20241008.1-6` | the update and reset stack | MIT, LGPL2.1, MIT, GPL | `holo/*` (404) |
| `deckard-audio-config 20261027.2-1` | PipeWire, WirePlumber, UCM2 and Valve's LV2/LADSPA plugins (section 6) | MIT | `deckard/deckardos/deckard-audio-config` (404) |
| `deckard-mesa-linux-aarch64`, `-x86_64`, `-android-aarch64 27.0.0_devel+gitb826d29e-1` | Valve's Mesa builds (section 6); `b826d29e` is not in mesa/mesa (`404 Commit Not Found`), so a Valve branch (*inference*) | `custom` | mesa3d.org |
| `fex-wtf 2606-5` | "Tool for seeing FEX emulator stats" | MIT | `github.com/Sonicadvance1/what-the-FEX` |
| `deckard-steam-rel`, `deckard-steamvr-rel`, `deckard-steamvr-session`, `lepton-compat` | the Steam client, SteamVR, their session, Lepton | not read (Steam client) | |

The hotfixes repo is also where Arch packages get Valve rebuilds with sub-release numbers (`bluez 5.79-1.6`, `chromium
129.0.6668.58-1.6`, `busybox 1.37.0-1.5`); the `mr-NNNN/` folders hold one package each (`mr-1133/` has
`deckard-steamvr-session-1.7.0-1`), so a merge request becomes a pacman repo before it reaches `goldmaster/`.

**Observed licence discrepancy.** `deckard-hw-support` is marked `Proprietary`, yet its initramfs hooks
(`usr/lib/initcpio/hooks/{partsets,blockdev_ro,etc_overlay,factory_reset}`) carry `SPDX-License-Identifier: GPL-2.0-only`
headers, and `deckard-boot-firmware` (also `Proprietary`) bundles a U-Boot binary (`U-Boot 2025.07-rc3-00656-gfbfd7e7ef9a0
for deckard board`, GPL-2.0-or-later upstream) with Qualcomm blobs. This note treats both packages as proprietary and
quotes nothing from them.

### What gbook could adopt (proposals)

- *Proposal:* add one `sources.md` row for the four new source kinds this note used: the gitlab.steamos.cloud API,
  the holo-packages listings and `.db.tar.xz`, the ISteamNews API, and GitHub's fork-network SHA resolution (this note
  did not edit `sources.md`).
- *Proposal:* none of the Frame's `deckard-*` source trees is public, so gbook cannot depend on them; the Arch-rebuilt
  repos are the only reproducible part, and even they float (`mash-*` snapshots are listed but their contents were not
  compared).

## 2. Rootfs and image build

**How the Frame image is assembled is not public.** The observable pieces:

- **Packages.** Arch Linux rebuilt for aarch64 at a "mash" snapshot (the preview readme credits Collabora for "the build
  infrastructure, developed the tooling required to build and publish packages"), plus Valve's packages built by GitLab
  CI (`builddir = /builds/deckard/deckardos/holo/deckard/linux-72-deckard` in the kernel's `.BUILDINFO`; `makepkg 7.1.0`).
  The pinned state is a snapshot name (`mash-20251118`), not a dated archive like snapshot.debian.org.
- **Image.** `holo/fakemachine` (debos' VM runner) is the only build-tool clue; that Valve builds images with debos is
  *inference*. The RAUC `system.conf` (LGPL, `steamos-customizations-deckard`) says:
  `compatible=steamos-aarch64`, `bootloader=custom`, `max-bundle-download-size=268435456`, `activate-installed=false`,
  two slots `rootfs.0` (bootname `A`, `/dev/disk/by-partsets/A/rootfs`, `type=raw`) and `rootfs.1` (`B`), a `[casync]`
  section with `use-desync=true` and `--seed /var/lib/steamos-atomupd/rootfs.caibx --in-place --error-retry 35`, and
  custom handlers (`bootloader-custom-backend.sh`, which creates the `by-partsets` links on old layouts and then calls
  `/usr/bin/splctl`). So a root slot is one raw image, delivered as a casync index and chunks, written in place.
- **Immutability.** The root is read-only (partner docs: `steamos-readonly disable`); `/etc` is an overlay whose upper
  directory lives in the slot's `var` partition (`var-A`/`var-B`, mounted by the `etc_overlay` initramfs hook); `/home`
  is shared and holds "offload" bind mounts for `/root`, `/var/log`, `/var/lib/flatpak`, `/var/cache/pacman` and
  others (`*.mount` units in the customizations package); `usr/lib/repart.d/90-home.conf` (`Type=home`) lets
  systemd-repart grow it. `atomic-update-keep.conf` lists the `/etc` paths that survive an update.
- **Update channels.** `etc/steamos-atomupd/client.conf`: `ImagesUrl = https://steamdeck-images.steamos.cloud/`,
  `MetaUrl = https://steamdeck-atomupd.steamos.cloud/meta`, `Variants = vr`, `Branches = stable;rc;beta;bc;preview;pc;main`.
  The same file carries a shared `Username`/`Password` for the image server; not reproduced here.
- **Signing.** RAUC bundles verify against `/etc/rauc/trusted_keys/` (plus a `development_keys/` directory); the older
  `deckard-atomupd-config` ships one self-signed certificate, subject and issuer `O=Valve, CN=Valve`, `notBefore`
  2023-05-24 22:10:05 GMT, `notAfter` 2027-03-24 22:10:05 GMT (`openssl x509 -noout -subject -issuer -dates` on the
  extracted file, 2026-11-05; the certificate itself is not copied). Packages carry `.sig` files; the preview's `pacman.conf` sets `SigLevel = Optional`.
- **Initramfs.** mkinitcpio (`dracut 111-1` is also in extra). `etc/mkinitcpio.conf.d/steamos.conf` adds the hooks
  `blockdev_ro partsets initrd_shell factory_reset etc_overlay deckard_fw`, the binaries `splctl fw_printenv fw_setenv
  bash strace zstd lsblk`, and `regulatory.db`. The post hook `usr/lib/initcpio/post/deckard-uimage` (LGPL) wraps the
  result with `mkimage -A arm64 -O linux -T ramdisk -C none` into `/boot/initrd.uImage`.
- **Compared with gbook.** gbook pins one Debian snapshot and keeps a lock list and manifest (`build-rootfs.sh`); the
  Frame pins a package snapshot by name and ships raw slot images with delta updates. gbook has one root partition on
  the stick; the Frame has two root slots, two `var` slots, one `home`. gbook signs a FIT for depthcharge with a dev
  key; the Frame signs RAUC bundles with Valve's CA, and whether anything checks a signature on the raw `Image` and
  the `mkimage -T ramdisk` initrd before the kernel runs is unknown (`verify=n` in `uboot.env` only disables U-Boot's
  image data-checksum check; see section 5).

### What gbook could adopt (proposals)

- *Proposal (M4):* name partitions the partsets way, `rootfs-A`/`rootfs-B`, `var-A`/`var-B`, `home`, and resolve
  `self`/`other` from one kernel-command-line token (the Frame uses `rauc.slot=A|B`; the `partsets` hook parses it).
  gbook's `/init` already finds ROOT through depthcharge's `kern_guid=%U`; the same token could pick the matching root
  slot. The hook is GPL-2.0-only inside a proprietary package, so re-implement, do not copy.
- *Proposal (M4):* read-only root with an `/etc` overlay in a writable slot partition. This is what makes "Previous
  slot" a real rollback: user state lives in `var-X` and `home`, never in the root image.
- *Proposal (M3, cheap):* an initramfs "shell with auto-reboot": the Frame's `initrd_shell` prints "Headset will
  auto-reboot in 20..." and stops the countdown on a keypress, a serial character or an adb connection, with
  `gotoinitrd=yes` or `break` on the command line forcing the shell. gbook's capture-and-reboot `/init` could add the
  countdown and the `break` escape without changing its sweep.
- *Proposal (M3):* lock the stock partitions read-only at the block layer from `/init` (`blockdev --setro` on every
  partition of the stock disk), which enforces CLAUDE.md's "never write AP or EC firmware" rule mechanically. The idea
  comes from the proprietary `blockdev_ro` hook; a one-line re-implementation needs no code from it.

## 3. Kernel

**Tree and version.** `linux-72-deckard` is `7.2.0-g344f27110f05`: `compare v7.2...344f27110f05` gives `ahead 1178,
behind 0`, merge base `8d3ae59288f1` "Linux 7.2" (2026-08-16). `linux-618-deckard` is `v6.18` plus 1,215. Committer
dates of the 1,178: 987 in 2026-08 (a rebase onto 7.2 on 2026-08-24, *inference*), 58 in September, 132 in October,
1 in November. Author domains: valvesoftware.com 501, linaro.org 359, arcturus.industries 85, gmail.com 78,
marek.ca 57, tgoyen.com 37, quicinc.com 16, oss.qualcomm.com 16, igalia.com 10, intel.com 5, collabora.com 3.
Subject prefixes: `gabe_defconfig` 68, `Revert` 62, `fixup!` 60, `HACK` 44, `WIP` 9, `FROMLIST` 9, `FEX` 2, `TEMP` 1.
One CI commit says "Don't run pipelines in linux-valve-publicly-released-branches" (`d643bc7139a5`), so a public
branch is planned or exists somewhere this search did not find (*inference*). The full subject list is in the
scratchpad (`kdts/valve/all-1178.tsv`), not in git.

**Configuration** (from `linux-72-deckard-headers`' `build/.config`, `# Linux/arm64 7.2.0 Kernel Configuration`,
2,584 `=y` and 61 `=m`; a single `gabe_defconfig` maintained by 68 commits):

| Area | Frame (`gabe_defconfig`) | gbook (`~/.cache/gbook/build-a804c57/.config`) |
|---|---|---|
| Pages, VA, HZ, preempt | 4K, `VA_BITS=48`, `HZ=1000`, `PREEMPT=y`, `SCHED_CLASS_EXT=y`, `KVM=y` | `VA_BITS=52`, `HZ=250`, `PREEMPT=y` |
| cpufreq / cpuidle | `ARM_QCOM_CPUFREQ_HW=y`, default governor **performance**, `ARM_PSCI_CPUIDLE=y` with the `teo` governor; `# CONFIG_ARM_SCMI_PROTOCOL is not set` (SM8650 has no SCMI cpufreq) | `ARM_SCMI_PROTOCOL=y`, `ARM_SCMI_CPUFREQ=y`, `ARM_QCOM_CPUFREQ_HW=y`, schedutil, `ARM_PSCI_CPUIDLE=y` but no PSCI cpuidle on mica ([ADR 0009](../adr/0009-no-psci-cpuidle.md)) |
| GPU, display | `DRM_MSM=y` with DPU, DP, DSI; `DRM_PANEL_DECKARD=y` (Valve's dual-DSI panel driver), `# CONFIG_DRM_PANEL_EDP is not set` | `DRM_MSM=y`, panel-edp with patch 0001 |
| Audio | `SOUNDWIRE_QCOM=y`, `SND_SOC_WSA883X=y`, `WSA884X=y`, `MAX98390=y`, the four LPASS macros, the whole QDSP6 stack built in, `QCOM_Q6V5_PAS=y`, `QCOM_APR=y`; `# CONFIG_SND_SOC_SM8250 is not set` | `SOUNDWIRE_QCOM=y`, `WSA884X=y` |
| IOMMU | `IOMMU_DEFAULT_DMA_STRICT=y` (worked around in userspace, section 6) | `IOMMU_DEFAULT_DMA_STRICT=y` |
| Wi-Fi, BT | `ATH12K=m` (one of the few modules), `BT_QCA=y`, `BT_HCIUART_QCA=y` | `ATH12K=y`, `BT_QCA=y` |
| pstore | `PSTORE_RAM=y`, `PSTORE_CONSOLE=y`, `PSTORE_PMSG=y`, `ramoops` node in the DT | `PSTORE_RAM=y`, `PSTORE_CONSOLE=y`, no `ramoops` node in `dts/x1e80100-google-mica.dts` |
| Modules, signing | `MODULE_SIG=y`, `# MODULE_SIG_FORCE is not set`, `# KEXEC is not set` | |
| Android | `ANDROID_BINDER_IPC=y`, `ANDROID_BINDER_DEVICES="anbox-binder,anbox-hwbinder,anbox-vndbinder"` (for Lepton) | |
| Stray x1e80100 bits | `CLK_X1E80100_GCC=m`, `CLK_X1P42100_CAMCC=m`, `CLK_X1P42100_VIDEOCC=m` (modules, so not used on the Frame; *inference*) | |

**Device tree.** The production DTB in the kernel package is `sm8650-mp.dtb` (`model = "SM8650 MP rev1 4slam 2et"`,
`compatible = "qcom,sm8650-dv1", "qcom,sm8650"`, 9,488 lines decompiled), beside `sm8650-dv1/dv2/ev1/ev2/ev3*`,
`sm8650-mp-power`, `sm8650-mp-dbg`, `sm8650-el2-hdk`, `sm8650-ayaneo-*` and the HDK boards. U-Boot picks
`/boot/dtbqcom/sm8650-<variant>.dtb` (section 5). Compared with the mainline `sm8650-valve-deckard.dts`:

- Both run at EL2 without the DSPs: the mainline file `/delete-node/`s `ipa`, `gpu_zap_shader`, the five LPASS
  macros, `lpass_tlmm`, `remoteproc_adsp/cdsp/mpss`, `reserved_memory`, the three `smp2p` nodes and `swr0-3`, then
  redefines `reserved-memory` (`aop`, `ramoops` at `0x84a00000`, `cmd-db`, `smem`, `cpucp-fw`, `video`, `tz-stat`,
  four LPASS LPM pools, a 48 MiB `framebuffer` at `0xaf400000`). That is the full-DTS version of what gbook's
  `dts/mica-el2.fixups` does on top of an overlay (overlays cannot delete nodes), and it validates the approach.
- Mainline enables `gpu` (no zap node), `pcie0` with the WCN7850 as `pci17cb,1107` and its PMU regulators, `uart14`
  (`qcom,wcn7850-bt`), `uart15` console, `ufs_mem_hc`, `sdhc_2`, `usb_1` as a USB 2.0 **peripheral** (`dr_mode =
  "peripheral"`, `maximum-speed = "high-speed"`, USB 3 PHY removed), four I2C buses with two `maxim,max98390`
  amplifiers (`Speaker Left`/`Right`), `gpio-keys`, PMIC temperature alarms; `dispcc` is disabled and the
  `simple-framebuffer` under `chosen` is 4320x2160 ARGB8888 "Bootloader will enable the node".
- The production DTB adds what is still out of tree: the `deckard-panel` (`dual-panel`, `low-fps-support`, eight
  supplies), the `qcom,lpass-sndcard` card ("SM8250 LPASS" model) driving `lpaif@7d00000` with the two MAX98390s on
  the "SPKR Playback" link and the VA macro DMIC on "VA Capture" (no ADSP: the DTB has no `remoteproc` node at all),
  `valve,fpga`, two `arcimx616` cameras plus eyes, `allegro,als31300`, PSCI `idle-states` for all three clusters
  (`arm,psci-suspend-param = <0x40000004>`, "silver/gold/gold-plus-rail-power-collapse"), `qcom,sm8650-cpufreq-epss`,
  `qcom,adreno-43051401` with its OPP table, and `qcom,pm8550b-charger`.

**Patch areas, against gbook's `kernel/patches/0001-0011`** (line 1 of each gbook patch read 2026-11-05; Valve-tree
commit messages and touched files read through the GitHub commit endpoint):

| gbook patch | Valve's tree carries | Overlap |
|---|---|---|
| 0001 `drm/panel-edp` LGD 0x0804 (LOCAL) | no `panel-edp`, `eDP` or `x1e80100` subject among the 1,178; the Frame's panel is DSI with its own driver | none |
| 0002-0007 "drm/msm: Attach a driver to GMU" (Akhil P Oommen, FROMLIST) plus the Omarchy fix-up | not the series. On GMU: `c76da00c0873` "a6xx_gmu: fixup bw voting to use AB voting" (+4 lines), `d36695feb7f3` "a6xx_gmu_wait_for_idle uses sleeps instead of spinning hard", `f43185c19923` "vote minimal opp on shutdown" (reverted in `272f8245e6f5`), `768a6e680987` "HACK: use correct register address for GMU AO cnter on a750" (reverted and reapplied twice). Two other Akhil commits are present: `00b93c80cab0` "drm/msm: Skip devfreq IDLE when possible", `e01f24c3b2f5` "drm/msm/adreno: Relax devfreq tunings". For the no-TZ GPU: `6eb3e65348d9` "HACK: drm/msm: adreno: add a7xx zap init", `afd29180cc00` "fix for a7xx without zap/tz" (one line in `sm8650.dtsi`), `c4eca5004b53` "enable back zap shader loading via SCM" | same area (GMU, EL2 GPU bring-up), different changes; nothing to copy for the stateless device-link problem |
| 0008 `gcc-x1e80100` PCIe GDSC retention (FROMLIST, Krishna Chaitanya Chundru), 0009 PCIe PHY GDSC retention (LOCAL) | no x1e80100 or PCIe-GDSC change. GDSC work is display and camera: `0ae07b602274` "clk: qcom: tie mdss gdsc to branch clocks" (`gdsc.c`, `clk-branch.c`, `dispcc-sm8550.c`), `a6ddcda546d1` "dispcc-sm8550: ... mdss_gdsc as ALWAYS_ON", `fb9ea49232da` "HACK: media: qcom: camss: add ALWAYS_ON flag to titan top and ife gdscs". PCIe: `f0aaa175a5f7` "pcie: qcom: add opt-in link_reset sysfs attr for PERST# pulse" (Arcturus), and the defconfig commits `ca6987de7ff9` "enable CONFIG_PCIEPORTBUS to allow the PCIe bus to go in D3Cold" and `9a8c8ea46950` "enable CONFIG_PCIEASPM to allow the PCIe endpoints to enter Lower energy levels" (both 2026-10-20/21) | none on the retention bit; Valve's endpoint low-power path is ASPM + port-bus D3cold rather than GDSC retention (*inference* from the two defconfig subjects) |
| 0010 `soundwire: qcom` re-arm enumerator after clock stop (LOCAL) | `603ad2317660` "WIP: soundwire: qcom: add some post bank switch delay" (cherry-picked from Srinivas Kandagatla: "on wsa883x we see Port Collision during bank switch"), `8f6efbaf3646` "HACK: soundwire: qcom: disable runtime pm" ("there's a bug somewhere that needs to be debugged", +17/-11 in `qcom.c`), `c5e49e3d99ac` "allow more rates and formats" (PDM-only bus) | same driver, same family of bug; Valve sidesteps clock-stop by disabling runtime PM (*inference*: no runtime PM means no clock-stop entry). No fix to copy, and these commits come from the EL2/HDK/Aya experiments (`65834eec3fcb` "aya el2 audio"), not from the production Frame, which has no SoundWire codec |
| 0011 `wsa884x` clock-stop mode 1 (LOCAL) | `9066a20246f7` "ASoC: codecs: wsa884x: remove mute_unmute_on_trigger" (with a `Fixes:` tag: "trigger is atomic ... soundwire register writes are not safe to run in an atomic context"), `ad9e0544ab85` the same for wsa883x, `5f9768d70cd3` "HACK: ASoC: codec: wsa884x: workaround for perma muted state" ("If the codec is unmuted and muted again immediately, no more audio will play ever again"), `24098704fd61`/`7f4b1c3f9436` "use older driver here" and its revert | same codec driver, mute and trigger path; no clock-stop-mode change |

Other Valve-tree work worth knowing (counts by subject): ath12k 65 (board-id from DT for a new diplexer, FTM/test mode,
txpower forcing, "work around dp_tx: failed to find the peer", forced RDDM and coredump, "fix survey indexing across
bands" from Collabora); display 109 (DSI CTRL v2.8.0, bonded-DSI DSC, a DPU "CAC" pipeline from Linaro, the
acronym unexpanded in the subjects, `drm/msm/dpu1: fix early delivery of page flip events`); camera 71; charger and fuel gauge 36
(`qcom_pm8550b_charger`, `max1720x`); IOMMU 8 (`iommu: arm-smmu-qcom: add display bypass if missing`, `defer attach
of nodes with iommu-defer-attach property`, an LPAC SID split); cpufreq `7ab3f57ab244` "set lowest freq and disable
OPP on cpu offline" and `a1190a326d84` "set suspend frequency"; PSCI `1b265e654037` "HACK: workaround for TZ PSCI
CPU_OFF/CPU_ON bug" (7 lines in `psci.c`, 4 in `irq-gic-v3.c`); EL2 plumbing `e9f42a84bfc1` "HACK: power: reset:
qcom-pon: add support for EL2 PS_HOLD control setup" and `55476188d208` "enable pmk8350-el2-pon to properly handle
reboot and shutdown"; `a9505502e5e8` "FEX: arch: arm64: Implement unaligned atomic emulation/backpatching" (2,056
lines in `arch/arm64/kernel/unaligned_atomic.c`, a new `prctl`); `ce749094e4ee` "hexagon-baremetal: adsp, cdsp, cvp
support" (*inference* from the subject and the DTB's lack of `remoteproc` nodes: Valve runs the DSP cores without the
Qualcomm remoteproc stack; out of gbook's scope).

### What gbook could adopt (proposals)

- *Proposal (DTS, needs dt-validate and ADR 0004 tracing):* a `ramoops` reserved-memory node for mica. gbook already
  builds `PSTORE_RAM=y` and `PSTORE_CONSOLE=y`, so a region makes the last console survive a hang. The Frame uses
  `0x84a00000` (1 MiB mainline, 2.25 MiB in the production DTB); mica needs its own address chosen against the stock
  reserved-memory map, and the choice is "unverified" in `dts/README.md` terms until a stock pin is found.
- *Proposal (kernel/mica-pcie.config, measure first):* try `PCIEASPM` and `PCIEPORTBUS` before extending the GDSC
  retention patches: the Frame reaches endpoint low power that way on a sibling SoC. A boot-rate claim would need
  `attempt.sh tally` for both configurations (CLAUDE.md).
- *Contrast, not adoption:* the Frame keeps PSCI cpuidle on, with a seven-line TZ CPU_OFF/CPU_ON hack and the `teo`
  governor. gbook's ADR 0009 removes PSCI cpuidle because the per-CPU domains lose `cluster_c4`; a different SoC and a
  different symptom, so ADR 0009 stands; the hack's diff is the thing to read if mica ever shows CPU_OFF failures.
- *Contrast:* Valve marks patch state in the subject (`HACK:`, `WIP:`, `FROMLIST:`, `fixup!`) and carries 62 reverts;
  gbook's `Status:` line and renumbering rule (ADR 0007, check 34) are stricter and should stay.

## 4. Firmware handling

Arch's split `linux-firmware-*` packages in core and one Valve package supply `/usr/lib/firmware` on the Frame
(file lists from `deckard-arch-hotfixes.files` and `core.files`); the two that matter here:

- `linux-firmware-qcom 20260519-1` (Arch's split package, `LicenseRef-WHENCE`, 163.2 MiB) in core, the same source
  gbook's `stage-firmware.sh` draws the GPU and audio-topology files from (`linux-firmware-qcom`, "20260916-1" on the build host).
- `linux-firmware-deckard 20261023.1+git594f649d-1` ("custom", 24.4 MB, 282 entries) in the hotfixes repo: the Adreno
  750 set at the **root** of the firmware directory (`a750_sqe.fw`, `a750_aqe.fw`, `a750_zap.mbn`, `gen70900_sqe.fw`,
  `gen70900_aqe.fw`, `gen70900_zap.mbn`, `gmu_gen70900.bin`; gbook's X1-85 loads `gen70500_sqe.fw` and
  `gen70500_gmu.bin` under `qcom/`), `ath12k/WCN7850/hw2.0/{amss,board,board_77,m3,regdb}.bin`, the QCA Bluetooth
  set (`qca/hmtbtfw20.tlv`, `hmtnv20.bin`, `hpbtfw21.tlv`, `hpnv21.bin`, `ht*`), `qcom/sm8650/{adsp,cdsp}.mbn`,
  `{adsp,cdsp}_dtb.mbn`, `adspr/adsps/adspua/cdspr/battmgr.jsn`, `ipa_fws.mbn`, `qupv3fw.elf`,
  `SM8650-MTP-tplg.bin`, `SM8650-QRD-tplg.bin`, `qcom/vpu/vpu33_4v.mbn`, `CAMERA_ICP.mbn`, `cvpss.mbn`, the
  MAX98390 `dsm_param*.bin` files, `i2c_fw.bin`, `spi_fw.bin`, `default.vrfont`/`default.vrterminal`, and the
  kernel.org `rtl_bt`, `rtl_nic` and `renesas_usb_fw.mem` sets. So it is a linux-firmware checkout with Valve's
  additions on top (*inference* from the mix); which files are Qualcomm-licensed is not stated beyond `custom`.
- The initramfs carries only `qcom/sm8650/qupv3fw.elf`, `dsm_param.bin` and the two `.vr*` files (`deckard_fw` hook)
  plus `regulatory.db`; everything else loads from the root.
- Boot firmware is a separate, proprietary package (section 5): `bootfw.tar.xz` holds `xbl.fw`, `xblconfig.fw`,
  `tz.fw`, `hyp.fw`, `aop.fw`, `aopconfig.fw`, `cpucp.fw`, `cpucpconfig.fw`, `devcfg.fw`, `shrm.fw`, `qupfw.fw`,
  `uefi.fw`, and zero-length `keymaster.fw` and `uefisecapp.fw` (sizes from `bsdtar -tvf`).

**Compared with gbook.** Same layout (kernel.org paths), same idea of a hash-checked set (pacman's `desc` holds the
package sha256; gbook keeps `kernel/firmware.sha256`), and the same two origins (a distro package plus device-specific
blobs). The difference is provenance: gbook's device blobs come from the stock `modem_a` partition the owner dumped
(ADR 0005), Valve's from Qualcomm under contract.

### What gbook could adopt (proposals)

- *Proposal:* nothing structural; `stage-firmware.sh` already matches. One check worth adding to `kernel/firmware.sha256`
  review: the Frame confirms that a7xx GPU firmware is versioned by chip (`gen70900` for the Adreno 750, `gen70500` for
  the X1-85), so a firmware bump that renames the file is a kernel-catalog change, not a packaging one
  (`a6xx_catalog.c:1573-1577` at the pin, per `stage-firmware.sh`'s header).

## 5. Boot flow, rootfs discovery, rollback and return to stock

**Partition map of the two boot LUNs** (GPT with 4 KiB sectors, parsed from the 256 MiB images in `deckard-boot-luns`;
names and sizes only, the content is proprietary):

- LUN 1 (28 entries): `xbl_a/b` (3,584 KiB each; `xbl_a` has attribute bit 2 set and type `dea0ba2c-cbdd-4805-b4f9-f428251c3e98`),
  `xblconfig_a/b` (240 KiB), `shrm_a/b` (256), `aop_a/b` (512), `aopconfig_a/b` (512), `cpucp_a/b` (1,024),
  `cpucpconfig_a/b` (64), `tz_a/b` (4,096), `devcfg_a/b` (128), `hyp_a/b` (8,192), `uefi_a/b` (32,768),
  `uefisecapp_a/b` (2,048), `keymaster_a/b` (512), `qupfw_a/b` (80). Every stage of Qualcomm's boot firmware is A/B.
- LUN 2 (14 entries): `bootenv`, `bootenvb` (128 KiB), `uboot_a` (32 MiB), `ubootenv_a` (128 KiB), `ubootfw_a`
  (4 MiB), the same three for `_b`, `uefivarstore`, `cdt`, `ddr`, `xblramdump`, `toolsfv`, `adpd`.
- The OS LUN (root slots, `var`, `home`, `esp`) is not in these images; the `blockdev_ro` hook locks `/dev/sdb`, `sdc`
  and `sdd`, so the OS lives on `/dev/sda` (*inference*). Sizes are unknown without the repair image.

**Boot chain, as far as the public artefacts show it.** Qualcomm PBL finds the XBL partition by a "magic parttype uuid"
(the `kernelsetup.sh` comment in the proprietary package says so; not quoted further) and runs the A/B boot firmware;
Valve's U-Boot (`U-Boot 2025.07-rc3-00656-gfbfd7e7ef9a0 for deckard board`, from `uboot.img` strings) then:

- shows the "Deckard Boot Menu" (ANSI or graphical) with entries `Current <slot>`, `Previous <slot>`, `Boot from USB`
  / `USB: <disk> [<n> GB]`, `Erase User Data`, `Repair Steam Installation`, `ADB mode`, `Battery Ship Mode`, each a
  `setenv slottarget ...`; `bootcount`, `bootlimit`, `altbootcmd` and `upgrade_available` are present (U-Boot's
  standard boot-count fallback; that Valve uses it is *inference*);
- loads `/boot/Image`, `/boot/initrd.uImage` and `/boot/dtbqcom/sm8650-<variant>.dtb` (`/boot/maindtb.dtb` as an
  alternative) from the chosen root partition; the strings show a `deckard_eeprom_init` symbol beside the
  `sm8650-%s.dtb` template, so the variant comes from the EEPROM (*inference*);
- builds the command line from a template ending `init=/sbin/init rauc.slot=<A|B> noresume rootwait earlycon`, with
  `root=PARTLABEL=<rootfs-A|rootfs-B>` ("Trying old rootfs partition names..." covers an older scheme), and the stored
  `default_bootargs=loglevel=3 rd.log=console rd.log=file id_aa64mmfr0.ecv=1`; the environment also holds
  `bootdelay=2` and `verify=n` (the whole `uboot.env` has three variables);
- can instead chain-load an EFI binary from `/efi/steamos/` (`deckard_bootefi`); the aarch64 `steamcl.efi` ("Stage 1
  bootloader for SteamOS 3+", the Deck's chainloader) is packaged. Which path a shipping Frame takes is not
  established; `fw_env.config` in `deckard-hw-support` says the Deck-style partsets-from-bootloader scheme is the goal
  "until that is working", so the direct U-Boot path is the current one (*inference*).
- Linux starts at EL2 (mainline DTS commit message). `hyp_a/b` partitions exist and `hyp.fw` is 1.6 MB, so what runs
  there, if anything, is unknown.

**In the initramfs:** `partsets` parses `rauc.slot=` (and `steamos.efi=`) and builds `/dev/disk/by-partsets/{A,B,self,other,shared}`;
`etc_overlay` mounts `by-partsets/self/var` and the `/etc` overlay; `factory_reset` mounts `esp` and, if
`/esp/efi/steamos/factory-reset/*.cfg` exists, re-creates `var-A`, `var-B` and `home` (`mke2fs -t ext4`, home with
`casefold`), zeroes `ubootenv_a/b` and reboots; `initrd_shell` starts `adbd` over USB FFS **inside the initramfs**
(vendor `0x28de`, product `0x2460`, "Steam Frame (initrd)") with the auto-reboot countdown.

**Updates to the boot firmware** (`deckard-boot-firmware`, proprietary; behaviour only): for the *inactive* OS slot,
write `uboot.img`, `ubootfw.img` and `uboot.env` to `uboot_<x>`, `ubootfw_<x>`, `ubootenv_<x>` when their hash differs
from the partition's; for the boot firmware, verify every `*.fw` against the *active* firmware slot, and if any differs
write all mismatching files to the *other* slot, read each back and compare, and only then `splctl set-bootfw-slot`.
Old layouts (EV2/EV3) get partition fix-ups. `splctl` (GPL-2.0+, the only public piece) also offers `force-slot A|B`,
`force-usb` and `set-state A|B good`.

**Rollback and return to stock, the first-party recipe** (Steam Support pages, read 2026-11-05):

| Need | Frame | gbook today |
|---|---|---|
| Boot the previous OS, keep data | hold **AUX**, press power, keep holding until the "SteamOS" menu, choose "Previous B" | KERN-A/KERN-B priorities exist in the ChromeOS GPT, gbook writes only KERN-A (ADR 0003) |
| Reset OS, keep games | "Repair Steam Installation" menu entry, or Settings > factory reset through `steamos-reset-tool` (`platform.toml`) | none |
| Wipe user data without booting | "Erase User Data" menu entry (`/efi/steamos/factory-reset`) | none |
| Reinstall from USB | boot menu (AUX + power), navigate with Volume Up/Down, select with AUX, boot the USB repair stick (4 GB image written with Rufus, Etcher or `bzcat` piped into `dd`), then "Wipe Device & Install SteamOS" from a desktop session | the stock recovery image on a USB stick (ADR 0001, Gate 1) |
| Unbrick the boot firmware | `steamframe-oobe-repair-qdl-...tar.gz` (4.1 GB): a QDL package, that is Qualcomm EDL flashing with the open `qdl` tool (*inference* from the name; not downloaded) | ChromeOS recovery mode; no EDL path documented |
| Know the state | "Purple, solid: Steam Frame is in bootloader" (LED reference) | the AP console over SuzyQ |

### What gbook could adopt (proposals)

- *Proposal (M4, the headline item):* write mica's recovery matrix in the same five rows, with the ChromeOS mechanisms
  that already exist: KERN-A/KERN-B `cgpt` priority, tries and successful bits are the analogue of Valve's slot state
  (`splctl set-state <slot> good` after a verified boot, `Previous` = boot the other kernel partition), the stock
  recovery stick is the analogue of the repair image, and the "Erase User Data" step is a `mke2fs` of the data
  partition from `/init`. The runbook already has the stick; what is missing is the documented "mark good" and
  "boot the other slot" commands, and a statement that there is no EDL path on mica.
- *Proposal (M3/M4):* carry the U-Boot update discipline into `attempt.sh`: write to the inactive slot, read back and
  hash-compare before switching. `attempt.sh verify` already hashes the stick; the "switch only after read-back"
  ordering is the part to keep when KERN-B comes.
- *Proposal (M3):* an initramfs `adbd`/`sshd` over the USB gadget is Valve's answer to "the device is off Wi-Fi";
  gbook's `rootfs-access.md` already studied `usb-drd` gadget mode (sources.md row "Reaching the booted rootfs"); the
  Frame shows it working from the initramfs, before the root is found.

## 6. Userspace: GPU, x86 emulation, audio

**GPU.** The Arch rebuilds provide `mesa 1:26.1.1-2` and `vulkan-freedreno 1:26.1.1-2` (extra, 2026-10-30); the
Frame runs Valve's own builds instead: `deckard-mesa-linux-aarch64 27.0.0_devel+gitb826d29e-1` ("native aarch64
build", 2026-11-04) ships `libvulkan_freedreno.so` (Turnip), `zink_dri.so`, `vkms_dri.so`, `libgallium-27.0.0-devel.so`,
`libgbm`, kmsro-named `*_dri.so` entries and the freedreno register XML; the 48-entry file list has no `msm_dri.so`
or `freedreno_dri.so`, so the build carries no freedreno GL driver and OpenGL goes through Zink on Turnip
(*inference* from the list). `deckard-mesa-linux-x86_64` is "FEX x86_64 build": a complete
x86_64 and i386 Mesa under `/usr/share/guestos/fex-mesa/usr/{lib,lib32}` (`libvulkan_freedreno.so`, `zink_dri.so`,
`graphics_provider.json`); that x86 games under FEX therefore use an x86 Turnip talking to the aarch64 kernel
directly rather than a thunk to the host driver is *inference* from the file list (the FEX blog describes thunks as
an option, and FEX-2610's notes mention "Vulkan thunks"). `deckard-mesa-android-aarch64`
is Mesa for Lepton's Android (`vendor/lib64/hw/vulkan.freedreno.so`, `libEGL_mesa.so`). `deckard-gamescope-layer-x86_64`
is a Vulkan layer for the x86 side (`gamescope 3.16.24-1` in extra). Upstream, the Adreno 750 work that names Valve
content is the Igalia MR for Half-Life: Alyx (`SP_CHICKEN_BITS_2` bit 30, "a performance uplift of 2.4%", applied only
to that title) and the FEX-driven Turnip override that makes uncached buffers cached-coherent "when this option is
set" (!41323). None of the three MRs states Valve funding; the blog does for the FEX team.

**x86 games.** FEX is not a system package: the LGPL `FEXBash` wrapper in `steamos-customizations-deckard` runs
`$STEAMPATH/steam/steamapps/common/FEX-Emu/fex-compat-tool` inside `SteamLinuxRuntime_4`, so FEX arrives as a Steam
depot ("compat tool") like Proton. `fex-wtf` ("what-the-FEX") is the stats viewer. Windows games go through Proton
(partner docs), native arm64 Linux builds through "Steam Linux Runtime 3.0 ARM64 (Sniper)", Android builds through
Lepton. The kernel side is the unaligned-atomic emulation commit (section 3), which the FEX blog credits for a 5x
latency improvement on unaligned atomics on the Frame's Cortex-X4 versus the X925.

**Audio.** PipeWire `1:1.6.6-1`, WirePlumber `0.5.14-1`, `alsa-ucm-conf 1.2.15.3-1` (extra). `deckard-audio-config`
(MIT) adds: UCM2 card files `conf.d/SM8250_LPASS/{SM8250_LPASS,HiFi}.conf` and `conf.d/LPASS-SNDCARD/...` with
`codecs/sm8250-lpass/{SpkrEnableSeq,VAEnableSeq}.conf` (the kernel card is `qcom,lpass-sndcard`, model "SM8250
LPASS"); WirePlumber rules that, for `alsa_card.platform-*`, set `api.acp.disable-pro-audio = true` and
`device.routes.default-sink-volume = 0.6`, and for `alsa_output.platform-*` force `S16LE`, 48,000 Hz, two channels
`FL,FR`, `api.alsa.period-size = 256`, `api.alsa.headroom = 1024`, `node.force-quantum = 480`, priority 800
(`50-alsa-config.conf`); `51-alsa-disable.conf` disables three nodes by name
(`alsa_output.platform-6b80000.lpass.playback.2.0`, `.3.0`, `alsa_input.platform-6b80000.lpass.capture.4.0`);
spatial audio with a virtual 7.1 option (`60-spatial-audio.conf`, `70-spatial-node-config.conf`, `spatial-node-config.lua`);
microphone processing with CPU and DSP echo-cancellation filter chains and a `microphone-tracker.lua`; Valve's
plugins `valve_boulder_speakers.lv2`, `valve_denver_speakers.lv2`, `valve_deckard_mic.lv2` (built with `faust2lv2`,
the Makefile says) and LADSPA `vraudiocompositor.so`; a `deckard-audio-setup.service` and PipeWire/WirePlumber user
drop-ins for SteamVR. The 0.5.6 and 0.5.7 notes add echo cancellation for external microphones and a fix for "audio
would stop working with USB or Bluetooth speakers if an application tried to access the microphone".

**Compared with gbook.** mica's speakers are WSA884x over SoundWire behind the ADSP (q6apm) with a topology file,
which is the X1E80100 path; the Frame drives the LPASS from the application processor with I2C/I2S MAX98390 amplifiers
and no DSP, so its UCM and kernel audio bits do not transfer. Its WirePlumber layer does.

### What gbook could adopt (proposals)

- *Proposal (M3 audio, cheap):* a `wireplumber.conf.d` drop-in for mica's card that fixes format, rate, period and
  quantum and disables the PCMs that are not wired (the Frame disables three by node name), instead of hiding unusable
  DAI links in the DTS. The current `scripts/audio-state.sh` read gives the node names.
- *Proposal (M3 Wi-Fi):* the `60-ath12k-iommu-fq.rules` udev rule (LGPL, two lines) switches the WCN7850's IOMMU group
  to `DMA-FQ`; its own comment gives the trade-off: with `IOMMU_DEFAULT_DMA_STRICT=y` "every RX buffer unmap does a
  synchronous SMMU TLB sync with IRQs off (~32% of NET_RX samples)", and "a write-after-unmap bug corrupts memory
  silently instead of raising an SMMU fault". gbook builds `IOMMU_DEFAULT_DMA_STRICT=y`, so the same CPU cost applies;
  try it only with a measured before/after, and never on a debugging boot.
- *Proposal (later, suspend):* `ath12k-irq-respread.sh` (LGPL) records each ITS MSI's effective CPU before suspend and
  pins it back after resume, because non-managed MSIs stay on CPU 0 after CPUs are hot-unplugged. Relevant once mica
  suspends.
- *Proposal (tooling):* `steamos-manager`'s device TOML shows GPU limits set through devfreq sysfs and CPU caps
  through cpufreq policies, both from userspace. gbook's `attempt.sh trace` could read the same sysfs nodes for the
  X1-85 when GPU clocks become a question; no kernel change.

## Not found / not public

- No SteamOS-for-ARM source repository, image recipe or build pipeline: `potato/mash/*`, `potato/smash/holo`,
  `deckard/deckardos/{holo,linux-valve,linux-firmware,u-boot,steamos-efi,deckard-hw-support,deckard-audio-config,...}`,
  `holo/{holo,steamos-efi,steamos-reset,atomupd-daemon,steamos-atomupd-client}` all answer 404 to the public API
  (2026-11-05); GitLab blob search needs a token (401). `holo-core-aarch64-preview` has no licence file of its own.
- Valve's kernel tree has no public branch or tag that this search found (`search/commits?q=hash:` returns 0 for both
  tips; no `linux-valve` repository on GitHub); the commits are readable only by SHA through GitHub's `torvalds/linux`
  endpoint. Cite them by SHA with that caveat.
- Mesa `b826d29e` is not in `mesa/mesa`.
- The repair image (4.07 GB) and the QDL package (4.10 GB) were not downloaded, so the OS LUN's partition sizes, the
  root filesystem type (U-Boot carries btrfs and ext4 code; the factory reset formats `var` and `home` as ext4), the
  installer's steps and the EDL flashing procedure are unread. The preview's `system.rootfs.zst` (385 MB) likewise.
- The proprietary packages (`deckard-boot-firmware`, `deckard-boot-luns`, `deckard-boot-images`, `deckard-hw-support`)
  are described from their file lists, strings and GPT headers only.
- `deckard-steam-rel` (671 MiB) and `deckard-steamvr-rel` were not read; where FEX's binaries land on disk is known
  only from the `FEXBash` wrapper's paths.
- The Steam Frame release notes name no kernel, Mesa or firmware versions; the store page says "SteamOS 3", the notes
  say "SteamOS 0.x (for Steam Frame)".
- No first-party statement ties the Igalia or Connor Abbott Mesa work to Valve funding.

## Sources

| URL | What it is | Read | Pin / commit | Licence |
|---|---|---|---|---|
| `https://api.github.com/orgs/ValveSoftware/repos` | Valve's GitHub organisation (55 repos) | 2026-11-05 | `steamos_kernel` last push 2023-05-22 | NOASSERTION |
| `https://gitlab.steamos.cloud/api/v4/projects` (`?search=`, `/<id>/repository/{tree,files,commits,branches,tags}`) | Valve's GitLab, public projects and files | 2026-11-05 | per project above | per project |
| `https://gitlab.steamos.cloud/holo/holo-core-aarch64-preview` | Arch aarch64 preview package sources | 2026-11-05 | `67f0d559` | none stated |
| `https://holo-packages.steamos.cloud/holo-core-aarch64-preview/mash-20251118.3/` | preview binary repo (`pacman.conf`, `pacman.mirrorlist`, `system.rootfs.zst`) | 2026-11-05 | `mash-20251118.3` (2026-07-10) | per package |
| `https://gitlab.steamos.cloud/frame-public/lepton` | Lepton | 2026-11-05 | `5964972a`, `v3.0.10` | MIT, GPL-3.0 |
| `https://gitlab.steamos.cloud/frame-public/frame-developer-tools` | developer tools, `pacman/deckard-pacman-src` | 2026-11-05 | `16d1942e` | none stated |
| `https://gitlab.steamos.cloud/SteamHardware/SteamFrame` | hardware references | 2026-11-05 | `bdbb41ba` | CC-BY-NC-SA-4.0 |
| `https://gitlab.steamos.cloud/holo/steamos-manager` (`data/devices/steam-frame.toml`, `data/platform.toml`) | SteamOS Manager | 2026-11-05 | `a3b20137` | MIT |
| `https://gitlab.steamos.cloud/holo/fakemachine` | fakemachine fork | 2026-11-05 | `74dd229b` | Apache-2.0 |
| `https://steamdeck-packages.steamos.cloud/archlinux-mirror/` | Deck/Machine package mirror (x86_64) | 2026-11-05 | listing | |
| `https://holo-packages.steamos.cloud/archlinux-deckard/archlinux/main/{core,extra}/os/aarch64/` and `core.db.tar.xz` | Frame base repos | 2026-11-05 | newest 2026-10-30 | Arch's |
| `https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/` with `deckard-arch-hotfixes.{db,files}.tar.xz` | Frame Valve packages; eight packages downloaded and read: `linux-72-deckard`, `-headers`, `deckard-boot-firmware`, `deckard-boot-luns`, `deckard-atomupd-config`, `deckard-audio-config`, `deckard-boot-images` (listed only), `steamos-customizations-deckard`, `deckard-hw-support`, `steamos-efi` | 2026-11-05 | newest 2026-11-04 | per package (table in section 1) |
| `https://steamdeck-images.steamos.cloud/recovery/` | repair images (`HEAD` only) | 2026-11-05 | `20260922.5153644-0.3.0` | not stated |
| `https://store.steampowered.com/steamos/download/?ver=steamframe` | download page (redirect target read from its HTML) | 2026-11-05 | | |
| `https://github.com/torvalds/linux/commit/f905cb6e600a` and `abbbaa99ac66` | Valve Deckard DTS and binding | 2026-11-05 | `f905cb6e600a` | BSD-3-Clause / GPL-2.0 |
| `https://api.github.com/repos/torvalds/linux/commits/344f27110f05` (and `compare/v7.2...`, `commits?sha=...&path=...`) | Valve's kernel commits through GitHub's fork network | 2026-11-05 | `344f27110f05`, `ee93c0d9394b`, base `8d3ae59288f1` | GPL-2.0-only |
| `https://patchwork.kernel.org/api/patches/?q=deckard&project=linux-arm-msm` | Deckard follow-up patches | 2026-11-05 | | |
| `https://partner.steamgames.com/doc/steamhardware/steamframe` and `/setup`, `/debugging`, `/loadgames`, `/compat`, `/engines/custom` | Steam Frame developer documentation (fetched with firecrawl) | 2026-11-05 | | Valve |
| `https://help.steampowered.com/en/faqs/view/1B71-EDF2-EB6D-2BB3`, `65B4-2AA3-5F37-4227`, `2668-0B6E-79E0-A85B`, `4F01-E85C-4977-EA0E` | Steam Support: recovery, install, Frame guide, LEDs | 2026-11-05 | | Valve |
| `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=4165890` | SteamOS-for-Frame release notes | 2026-11-05 | 0.3.0 … 0.5.7 Beta | Valve |
| `https://store.steampowered.com/sale/steamframe` and the 2026-09-14 announcement post | product page and launch post | 2026-11-05 | | Valve |
| `https://github.com/FEX-Emu/FEX`, `https://fex-emu.com/Scourge-of-emulation/`, `https://fex-emu.com/FEX-2610/` | FEX and its blog | 2026-11-05 | `FEX-2610` | MIT |
| `https://github.com/bylaws/linux/commit/7ae989a43ae7e3cb8007ac21c28dacc24c9d8320` | the unaligned-atomics patch as published by its author | 2026-11-05 | branch `fex-unaligned-atomic` | GPL-2.0 |
| `https://gitlab.freedesktop.org/api/v4/projects/176/merge_requests/{41323,44840,44348,45615}` | Mesa Turnip MRs | 2026-11-05 | merged 2026-05-08, 10-06, 09-14, 10-27 | MIT |
| `~/.cache/gbook/linux-a804c57`, `~/.cache/gbook/build-a804c57/.config`, `kernel/patches/*.patch` line 1, the three script headers | gbook's own pin, config and patch list | 2026-11-05 | `a804c57` | |

## Decisions (owner, 2026-11-05, 10:52 AM EST)

Grilling round on the five candidates; the owner took every recommendation:

1. **M4 recovery matrix**: write it now as the M4 planning doc, before any SSD work (Valve's five rows mapped onto ChromeOS mechanisms).
2. **`ramoops`**: add on a later diagnostic boot, with a stock-safe address and ADR 0004's "unverified" marking.
3. **ath12k IOMMU DMA-FQ rule**: measure first, one boot with the rule, iperf against a LAN host before and after; never on a debugging boot.
4. **WirePlumber per-card drop-in**: adopt when PipeWire enters the rootfs.
5. **Initramfs**: the block-layer read-only lock of the stock partitions from `/init` now (re-implemented, not copied); the auto-reboot
   countdown shell later, with M4.

Each is on the task list (`TaskList`); this note is the source they cite.

