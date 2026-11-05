# M3 rootfs: which distribution, and how it boots from the stick

Researched 2026-11-04 (written 1:03 PM ET) on the build host. Sources: distro package indexes and package pages, Mesa and Ghostty
upstream at named commits and tags, the Omarchy repositories at named commits, the kernel tree at the pin
(`~/.cache/gbook/linux-a804c57`, `a804c5742bff`, with local patches applied in `drivers/gpu/drm/msm` and elsewhere,
not in `block/`, `fs/` or `init/`), the cached vboot source in `.firecrawl/`, and the built kernel's
`~/.cache/gbook/build-a804c57/.config`. The Googlebook was not touched: no adb, no `gbook`, no SuzyQ. Nothing was
installed. *Inference* marks what no source states. All package versions are as read on 2026-11-04 and will move.

Context: [ADR 0010](../adr/0010-milestones-status-upstream-hold.md) sets M3 as "a rootfs from USB with Mesa on the GPU
and Wi-Fi in userspace; the audio state is known; the first release tag" ([ADR 0011](../adr/0011-versions-and-releases.md)).
The boot path is the dev-signed FIT on KERN-A ([ADR 0003](../adr/0003-first-boot-chromeos-kernel-partition.md),
[fit-packaging.md](fit-packaging.md)), and the kernel stays ours: torvalds `a804c57` plus `kernel/patches/`, every
needed driver built in.

## Answer

1. **Debian sid arm64 for M3**, built by `mmdebstrap` in the same digest-pinned sid container that packages the image,
   pinned to one snapshot.debian.org timestamp, with a lock list and a local `.deb` cache (snapshot answered 503 today).
2. **Mesa does not decide it.** Every candidate ships Mesa 26.x; the Adreno X1-85 is supported since Mesa 24.2.0, and
   Mesa's kmsro path should drive our split `msm-kms` + `msm` devices (*inference* from source).
3. **Ghostty decides the runner-up.** Only Omarchy's aarch64 repo has a 1.4.0 binary; Debian has no Ghostty at all.
   Recommended: build 1.4.0 from its signed source in the container, as Omarchy's PKGBUILD does (owner question 2).
4. **Boot (inference):** ROOT is partition 2 on the same stick from 256 MiB on, so the per-attempt 256 MiB `dd` never
   touches it; `/init` finds ROOT through depthcharge's `kern_guid=%U`, copies its log, Wi-Fi block and stock firmware
   into the new root's `/run`, and `switch_root`s. No ROOT, and it falls back to today's capture-and-reboot.
5. **Omarchy aarch64 (Arch Linux ARM base) is the natural M4 base:** Ghostty 1.4.0, Quickshell and Hyprland are in its
   repo, and the owner runs Omarchy on the build host. It lacks a dated pin, which matters for M3's release tag.

| | Debian sid | Arch Linux ARM + Omarchy aarch64 | Ubuntu 26.04 / 26.10 | Fedora 44 / 45 | postmarketOS (Alpine edge) |
|---|---|---|---|---|---|
| Mesa (X1-85 since 24.2.0) | 26.2.6 | 26.2.6 (ALARM), 26.2.5 (Omarchy's mirror) | 26.0.8 / 26.2.4 | 26.2.6 / 26.2.3 | 26.2.6 |
| GTK 4 / libadwaita (Ghostty 1.4 needs 4.18 / 1.7) | 4.24.1 / 1.10.0 | 4.24.1 / 1.10.0 | 4.22.4 / 1.9.1; 4.24.1 / 1.10.0 | 4.22.5 / 1.9.4; 4.24.1 / 1.10.0 | 4.24.1 / 1.10.0 |
| Ghostty arm64 | none (community 1.3.1 `.deb`) | **1.4.0** (Omarchy repo; not in ALARM) | 1.3.0 (universe) | none (COPR, Terra) | 1.3.1 git, `testing` only, musl |
| Dated pin | snapshot.debian.org | none found | archive only; ports not confirmed | none found (koji NVRs) | none found |
| Built in the existing sid container | yes (`mmdebstrap` 1.6.0-5) | possible (`pacman` 7.1.0, `arch-install-scripts` 32 in sid; keyrings are not) | likely (*inference*) | possible (`mkosi` 27.1, `dnf` 4.24 in sid; *inference*) | possible (`pmbootstrap` 3.12.1 in sid) |
| Takes our kernel and `/init` | yes | yes | yes | yes | only by bypassing its own initramfs (*inference*) |

## 1. What every candidate shares

### Mesa and the Adreno X1-85

- **Support landed in Mesa 24.2.0.** Rob Clark's "freedreno: Enable the X1-85" (`b0d22461b945`, MR
  [!30249](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/30249), merged 2024-07-18) is first contained in
  tag `mesa-24.2.0` (GitLab API `commits/<sha>/refs?type=tag`, read 2026-11-04).
- **Mesa 24.3.0 is the practical floor.** "freedreno: Add compute constlen quirk for X1-85" (`3c8190e8b221`, MR
  [!31764](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/31764)) halves the compute constlen, because
  without it "there are sporadic hangs in dEQP-VK.robustness.robustness2.*" on the GPU "in x1e laptops". It is first in
  `mesa-24.3.0`.
- **The device entry.** Mesa main `32f5c9344041` has `GPUId(chip_id=0xffff43050c01, name="Adreno X1-85")` in the a7xx
  "gen2" group with the a740 (`src/freedreno/common/freedreno_devices.py:1242`; at `mesa-26.2.0`, line 1262). The kernel
  binds `qcom,adreno-43050c01` and loads `gen70500_sqe.fw` and `gen70500_gmu.bin`
  ([gpu-2026-11-03.md](../recon/gpu-2026-11-03.md)).
- **GL and Vulkan.** The freedreno page says the gallium driver "implements up to OpenGL ES 3.2 and desktop OpenGL 4.5",
  and Turnip "is a Vulkan 1.3 driver for Adreno 6xx GPUs" ([docs.mesa3d.org/drivers/freedreno.html](https://docs.mesa3d.org/drivers/freedreno.html),
  read 2026-11-04; it names no a7xx part). At `mesa-26.2.0`, `freedreno_screen.c:518-526` sets GLSL feature level 460
  for every `is_a6xx()` screen except a702, and `is_a6xx()` is `screen->gen >= 6` (`freedreno_screen.h:275-278`), which
  includes a7xx.
- **Every candidate clears both floors** (versions in the table above). So Mesa does not decide the distribution.

### Mesa on our split DRM devices (inference from source, untested on mica)

`msm.separate_gpu_kms=1` is on the base command line (`scripts/package-in-container.sh`). At the pin, the display then
registers as DRM driver `msm-kms` and the GPU as `msm` (`drivers/gpu/drm/msm/msm_drv.c:885, 904`); on mica they were
`card2` and `renderD128` ([gpu-2026-11-03.md](../recon/gpu-2026-11-03.md)).
- Mesa's pipe loader has no descriptor named `msm-kms`, so it falls back to kmsro: "kmsro supports lots of drivers, try
  as a fallback" (`src/gallium/auxiliary/pipe-loader/pipe_loader_drm.c:181-183` at `mesa-26.2.0`, `:174` at
  `mesa-26.0.0`).
- kmsro opens a render node, and when its kernel driver is `msm` it creates a freedreno renderonly screen
  (`src/gallium/winsys/kmsro/drm/kmsro_drm_winsys.c:100-103` at `mesa-26.2.0`; `:99` at `mesa-26.0.0`).
- *Inference:* a compositor on `card2` renders on the X1-85 through kmsro. M3's first rootfs boot checks this before
  anything else ([4.4](#44-showing-the-m3-criteria)).

### Ghostty's floor

- **GTK and libadwaita.** "1.4.x | 4.18 | 1.7"; 1.3.x needs GTK 4.14 and libadwaita 1.5. The rule is "the minimum
  version that is available in the most recent LTS releases of Debian, Fedora, and Ubuntu"
  ([ghostty.org/docs/linux](https://ghostty.org/docs/linux), read 2026-11-04).
- **OpenGL.** "We require at least OpenGL 4.3" (`src/renderer/OpenGL.zig:38-40` at tag `v1.4.0`). *Inference:*
  freedreno's GLSL 460 level and "up to OpenGL 4.5" clear it. `eglinfo` on the device settles it.
- **Release.** Tag `v1.4.0` is dated 2026-10-27 (GitHub tag object `ce787fc18a77`). Ghostty is MIT-licensed (Omarchy's
  PKGBUILD `license=(MIT)`).
- **Building it.** Omarchy's PKGBUILD builds 1.4.0 from `https://release.files.ghostty.org/1.4.0/ghostty-1.4.0.tar.gz`
  with a pinned upstream Zig: "Ghostty 1.4.x requires Zig 0.17.x", fetched from `ziglang.org` for x86_64 and aarch64
  with sha256 sums (`pkgbuilds/ghostty/PKGBUILD` at omarchy-pkgs `66368e24e900`). Ghostty's build page lists the
  Debian build dependencies (`libgtk-4-dev libgtk4-layer-shell-dev libadwaita-1-dev gettext libxml2-utils`), says
  release tarballs carry minisign signatures, and does not mention cross-compiling. Its Zig table stops at 1.3.x
  ([ghostty.org/docs/install/build](https://ghostty.org/docs/install/build), read 2026-11-04). Debian sid has no `zig`
  package (madison, read 2026-11-04).

### Our kernel under a systemd userspace

Every candidate except postmarketOS boots systemd; Debian sid and ALARM both ship 262.1. systemd v262's `README`
"REQUIREMENTS" lists the kernel options it needs. The built config (read 2026-11-04) has `DEVTMPFS`, `CGROUPS`,
`INOTIFY_USER`, `SIGNALFD`, `TIMERFD`, `EPOLL`, `UNIX`, `SYSFS`, `PROC_FS`, `FHANDLE`, `DMIID`, `BLK_DEV_BSG`, `NET_NS`,
`USER_NS`, `IPV6`, `AUTOFS_FS`, `TMPFS_XATTR`, `SECCOMP`, `SECCOMP_FILTER`, `KCMP`, `CGROUP_BPF`, `BPF_JIT` and
`EFI_PARTITION` all `=y`, and `UEVENT_HELPER` off.
- **One mismatch:** `CONFIG_FW_LOADER_USER_HELPER=y` (from defconfig), where the README says "Userspace firmware
  loading is not supported and should be disabled in the kernel". `FW_LOADER_USER_HELPER_FALLBACK` is off.
  *Inference:* harmless in practice, but a one-line fragment turns it off.
- **Root filesystem and stick.** `EXT4_FS=y` and `USB_STORAGE=y`, but `USB_UAS` is not set, so the stick runs over
  bulk-only transport. *Inference:* slower than UAS, not wrong.
- **Modules.** `MODULES=y`, with 1450 symbols `=m`, but the initramfs loads none (`kernel/*.config` header,
  [status](../status.md) legend). [ADR 0011](../adr/0011-versions-and-releases.md) changes `uname -r` with every gbook
  commit, so modules baked into a write-once rootfs would stop matching after the next KERN-A-only rewrite.
  *Inference:* keep the all-built-in rule and add fragments (audio below) rather than ship `/lib/modules`.

### Firmware

- The stock ADSP and CDSP images (`qcom/x1e80100/google/mica/`) are vendor content: never in git and never in an image
  that leaves the build host ([ADR 0005](../adr/0005-vendor-content-out-of-git.md)).
- Everything else the boot loads is redistributable: ath12k, Bluetooth, the regulatory database, and the GPU pair.
  Debian's `firmware-qcom-soc` 20260916-1 (sid, non-free-firmware) carries `qcom/gen70500_sqe.fw`, `qcom/gen70500_gmu.bin`
  and `qcom/x1e80100/X1E80100-Dell-XPS-13-9345-tplg.bin` (packages.debian.org file list, read 2026-11-04). That is the
  same linux-firmware tag as `scripts/stage-firmware.sh`'s pinned `linux-firmware-qcom-20260916-1`.
- The firmware loader searches `firmware_class.path`, then `/lib/firmware/updates/…` and `/lib/firmware/…`. The path
  can also be set at run time through `/sys/module/firmware_class/parameters/path`
  (`Documentation/driver-api/firmware/fw_search_path.rst` at the pin).

## 2. The candidates

### Debian sid arm64 (mmdebstrap)

- **Mesa:** `mesa` 26.2.6-1 and `mesa-vulkan-drivers` 26.2.6-1 (arm64) in sid (qa.debian.org madison, read 2026-11-04;
  madison also still lists 26.2.5-1 for sid). Forky has 26.1.6-1.
- **Ghostty: no package.** madison and sources.debian.org return nothing for `ghostty`. GTK 4.24.1+ds-1 and
  `libadwaita-1` 1.10.0-2 exceed 1.4's floor. There are two routes:
  - **Build 1.4.0** from the signed tarball with Zig 0.17, as Omarchy's PKGBUILD does. Under qemu-user in the container
    it is slow, and the time is unmeasured. Cross-compiling is undocumented.
  - **A community `.deb`:** `ghostty_1.3.1-0.ppa2_arm64_forky.deb` (also trixie and Ubuntu builds) from
    [mkasberg/ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu) release `1.3.1-0-ppa2`, which ghostty.org lists as
    "Community".
- **Our kernel:** yes. A Debian rootfs needs no Debian kernel package; `systemd` 262.1-1 (sid) meets the requirements
  above.
- **Firmware and audio data:** `firmware-qcom-soc` (above), `alsa-ucm-conf` 1.2.16.1-1. Upstream alsa-ucm-conf
  `v1.2.16.1` has `ucm2/Qualcomm/x1e80100/Dell-Xps-9345.conf` and `Xps9345-HiFi.conf` (GitHub, read 2026-11-04).
- **Pinning:** snapshot.debian.org takes `archive/debian/<yyyymmddThhmmssZ>/` URLs, and apt needs
  `[check-valid-until=no]` for snapshots older than about twelve days ([snapshot.debian.org](https://snapshot.debian.org/),
  read 2026-11-04).
  - mmdebstrap: with `SOURCE_DATE_EPOCH` set, "the result will be reproducible across multiple runs with the same
    options and mirror content". For ext4 output, "the filesystem UUID and hash_seed will be set to a UUID derived from
    SOURCE_DATE_EPOCH" ([mmdebstrap(1)](https://manpages.debian.org/unstable/mmdebstrap/mmdebstrap.1.en.html),
    1.6.0-5, read 2026-11-04).
  - **Availability:** `snapshot.debian.org/archive/debian/2026110…/dists/sid/…` answered HTTP 504 and 503 on three
    tries on 2026-11-04. So the non-free-firmware component under snapshot is unconfirmed, and a local cache of the
    exact `.deb` files is needed regardless. The project already does this for firmware packages
    (`~/.cache/gbook/pkgs`).
- **Building on the build host:**
  - `mmdebstrap` lists "foreign architecture chroots using qemu-user" and checks the arch "using qemu binfmt_misc
    support".
  - the build host registers `qemu-aarch64` with interpreter `/usr/bin/qemu-aarch64-static` and flags `PF`
    (`/proc/sys/fs/binfmt_misc/qemu-aarch64`, read 2026-11-04). The `F` flag opens the interpreter at registration, so
    it also works inside a container (*inference*, from binfmt_misc semantics).
  - mmdebstrap's root mode "needs to be able to mount and thus requires CAP_SYS_ADMIN". *Inference:* the container then
    needs `--cap-add SYS_ADMIN` (or `--privileged`), which `package-image.sh` does not pass today. That is an owner-OK
    change.
  - Output can be an `.ext4` image directly. Offline rebuilds need the cached `.deb` set served as a local mirror
    (*inference*; not tried).
- **Licence:** main plus non-free-firmware (redistributable firmware). No stock blob goes in the image.
- **Size:** not measured. The stick is "4 GB+" (README owner tasks). Step 1 of the plan measures it
  ([4.7](#47-steps)).

### Arch Linux ARM + Omarchy aarch64

- **What Omarchy on aarch64 is.** Its aarch64 `pacman-stable.conf` enables `[omarchy]`
  (`https://pkgs.omarchy.org/stable/$arch`) ahead of `[core]`, `[extra]` and `[alarm]`. Those three come from "Omarchy's
  mirror of Arch Linux ARM", `https://arm-stable-mirror.omarchy.org/$arch/$repo` (`default/pacman/aarch64/` at omarchy
  `84b3f2872b50`, branch `quattro`). The Snapdragon set (`install/omarchy-aarch64-qualcomm.packages`) adds
  `linux-firmware-qcom`, `qcom-firmware-extract`, `systemd-ukify`, `vulkan-freedreno` and `pipewire-libcamera`.
- **Mesa:**
  - ALARM's mirror has `mesa` and `vulkan-freedreno` 1:26.2.6-1, while Omarchy's ALARM mirror has 1:26.2.5-1
    (`extra.db` of both, read 2026-11-04).
  - Omarchy's `mesa-aurora` is the Asahi driver only ("Aurora Asahi Gallium, Zink and Honeykrisp").
  - *Inference:* the lag between the two mirrors is Omarchy's curated "stable" channel.
- **Ghostty: 1.4.0-1 for aarch64** in Omarchy's stable repo (`omarchy.db`, 187 packages, read 2026-11-04), built by the
  PKGBUILD above. ALARM's own `extra` has no `ghostty`. GTK 1:4.24.1-1 and libadwaita 1:1.10.0-1 are in ALARM `extra`.
- **M4 continuity:** `quickshell` 0.3.2, `hyprland` 0.56.2 and `qcom-firmware-extract` are in the same aarch64 repo.
  Omarchy's Snapdragon install builds a UKI "with the device trees systemd-stub picks one from", which is a UEFI path.
  mica's depthcharge boots FIT kernel partitions, not UKIs, so the Omarchy installer does not fit as is. A pacstrapped
  rootfs with Omarchy packages would (*inference*).
- **Our kernel:** yes. ALARM's `linux-aarch64` (7.3.1-2) and Omarchy's `linux-omarchy` (7.2.8-13 in the aarch64 repo)
  are simply not installed.
- **Pinning: none found.** Arch's dated archive covers x86_64 only, and no official ALARM archive was found. The stable
  mirror is curated, not addressed by date. *Inference:* superseded packages leave the mirrors, so the local cache plus
  a lock list would be the only pin.
- **Building on the build host:** Debian sid ships `pacman-package-manager` 7.1.0-3 and `arch-install-scripts` 32-1. The
  ALARM and Omarchy keyrings are not in Debian. Package hooks run in the arm64 chroot under the same qemu binfmt
  (*inference*; not tried).
- **Licence:** free packages from ALARM. The Omarchy repo also carries proprietary apps, so only named packages are
  pulled.

### Ubuntu 26.04 "resolute" and 26.10 "stonking"

- **Releases:** 26.10 is the "Current Stable Release" (released 2026-10-15) and 26.04 is supported (Launchpad API
  `ubuntu/series`, read 2026-11-04).
- **Mesa:** 26.0.8-1ubuntu0.3 (resolute-updates) and 26.2.4-1ubuntu1 (stonking) (Ubuntu madison, read 2026-11-04).
- **Ghostty:** `ghostty` 1.3.0~us1-0ubuntu1.1 in resolute-updates/universe and 1.3.0~us1-0ubuntu4 in stonking, both
  with arm64 builds. ghostty.org lists Ubuntu as "Official, from 26.04". GTK is 4.22.4 and libadwaita 1.9.1 on 26.04,
  4.24.1 and 1.10.0 on 26.10, so either could run 1.4 if built.
- **Concept images for X1 laptops:** UEFI ISOs (`questing-desktop-arm64+x1e.iso`) that use SMBIOS "to load the correct
  dtb automatically". The page as served shows Mesa 24.2.3 and replies from November 2024, so it reads stale
  ([discourse.ubuntu.com/t/48800](https://discourse.ubuntu.com/t/ubuntu-concept-snapdragon-x-elite/48800), read
  2026-11-04). mica has no UEFI, so only Ubuntu's userspace would apply.
- **Our kernel:** yes, as for Debian.
- **Pinning:** snapshot.ubuntu.com covers the archive from 2023-03-01 ([snapshot.ubuntu.com](https://snapshot.ubuntu.com/),
  read 2026-11-04). arm64 lives on ports.ubuntu.com, whose `resolute` Release has no `Snapshots:` field, and
  `snapshot.ubuntu.com/ubuntu-ports/` answered 404 (read 2026-11-04). So no dated arm64 pin is confirmed.
- **Building on the build host:** *inference*: mmdebstrap can bootstrap Ubuntu suites with the Ubuntu keyring; not checked.

### Fedora 44 and 45

- **Mesa:** 26.2.6-1.fc44 (F44 updates) and 26.2.3-1.fc45 (mdapi `srcpkg/mesa`, read 2026-11-04).
- **GTK and libadwaita:** 4.22.5 / 1.9.4 on F44, 4.24.1 / 1.10.0 on F45.
- **Ghostty: none** in Fedora (mdapi returns nothing for rawhide, F44 or F45). ghostty.org lists COPR
  `scottames/ghostty` and Terra, both community; their arm64 builds were not checked.
- **X1E:** the Fedora wiki covers the "aarch64 Fedora Workstation 44 Live ISO" on X1E/X1P laptops with
  `clk_ignore_unused pd_ignore_unused systemd.tpm2_wait=0 modprobe.blacklist=qcom_q6v5_pas`, an EFI firmware path
  ([Snapdragon WoA Laptop Install](https://fedoraproject.org/wiki/Snapdragon_WoA_Laptop_Install), oldid 775997, read
  2026-11-04).
- **Our kernel:** yes. A Fedora rootfs without `kernel-core` is possible (*inference*).
- **Pinning:** no dated snapshot mirror found. Koji keeps every build by NVR.
- **Building on the build host:** `mkosi` 27.1-1 and `dnf` 4.24.0-1 are in sid. Whether either builds Fedora 45 arm64 there was not
  checked.

### postmarketOS (now Nura) on Alpine edge

- **Mesa:** Alpine edge `main/aarch64` has `mesa`, `mesa-dri-gallium` and `mesa-vulkan-freedreno` 26.2.6-r0
  (`APKINDEX`, read 2026-11-04). *Inference:* pmOS edge uses Alpine edge's Mesa (wiki.nura.eco was behind a bot check).
- **Ghostty:** 1.3.1_git20260908-r2 in `testing/aarch64` only (edge, not in a stable branch), built against musl.
  `gtk4.0` 4.24.1-r0, `libadwaita` 1.10.0-r0, `linux-firmware-qcom` 20260916-r0.
- **Our kernel:** pmOS's strength is the boot side: pmbootstrap already builds depthcharge images
  (`deviceinfo_generate_depthcharge_image`, cgpt layout, [fit-packaging.md](fit-packaging.md) section 5). x1e80100
  laptops are in pmaports (Yoga Slim 7x in `testing`, [milestones-versioning.md](milestones-versioning.md) section 1).
  But a pmOS device brings its own kernel package and its own initramfs. *Inference:* keeping our `/init` and its
  netlog means working around pmOS rather than with it.
- **Pinning:** none found for edge. `pmbootstrap` 3.12.1-1 is in sid.

## 3. Recommendation, and why

- **For M3, Debian sid.** It is the only candidate with a citable dated pin, and it builds in the container that
  already packages every image (same tool, same base). Its Mesa, GTK and libadwaita are as new as anyone's, and its
  non-free-firmware carries the GPU pair and the 9345 topology. The cost is Ghostty: build 1.4.0 (question 2).
- **For M4, revisit with Omarchy aarch64.** Ghostty 1.4.0, Quickshell and Hyprland come as binaries from the owner's
  own distro. The boot design in section 4 is distro-neutral: only the rootfs build script changes.
- **Not Ubuntu, Fedora or pmOS for M3.** Ubuntu adds Ghostty 1.3.0 but no confirmed arm64 pin. Fedora has no Ghostty
  and no pin. pmOS fights our `/init` and uses musl.

## 4. Boot design (inference throughout; no part of it has run on mica)

### 4.1 Stick layout

The owner rewrites the whole 256 MiB `mica-usb.img` for every attempt, GPT included (`scripts/attempt.sh dd-cmd`,
`scripts/package-in-container.sh`), and `attempt.sh verify` reads the same 256 MiB back.
- **ROOT starts at 256 MiB.** fit-packaging's sketch put ROOT at sector 270336, right after KERN-A
  ([fit-packaging.md](fit-packaging.md), step 5); a 256 MiB `dd` would overwrite its start. Start ROOT at sector 524288
  (256 MiB) and run it to the end of a declared size `D`.
- **The image's GPT declares ROOT.** Otherwise each kernel rewrite deletes the entry. `cgpt create` runs on a sparse
  file of size `D`, `cgpt add -i 2 -t data -l gbook-root` adds ROOT, and the first 256 MiB is cut out as
  `mica-usb.img`. The attempt `dd`, `verify` and `gpt` stay as they are. The container's offline `cgpt show`
  attribute checks and `cgpt.txt` then run on the full sparse file before the cut, because the cut file's backup
  header is not at its end (*inference*: cgpt's handling of an invalid backup header was not read).
- **`D` must not exceed the stick.** vboot rejects a primary header whose `last_usable_lba` lies beyond the drive
  (`firmware/lib/cgptlib/cgptlib_internal.c:144-146` at vboot `34fbbe6`). A backup header not at the drive's end fails
  its check (`:119-121`), and `GptRepair` rebuilds it in memory from the primary (`:337-358`).
  `WriteAndFreeGptData` then runs on every boot (`2load_kernel.c:783`). Whether it writes the repaired backup was not
  read (`gpt_misc.c` is not in the cache).
  - Today's image already has its backup header at 256 MiB, not at the stick's end, and it boots. So this case is
    tested in practice.
  - Linux warns "GPT:Alternate GPT header not at the end of the disk" and carries on with the primary
    (`block/partitions/efi.c:552` at the pin).
- **depthcharge ignores ROOT.** vboot considers only ChromeOS-kernel and Android-vbmeta type entries
  ([fit-packaging.md](fit-packaging.md) section 5).
- **Writing ROOT is a rare owner step:** `dd` of `rootfs.ext4` to sector 524288 (or to partition 2), named first and
  run with `!` like the kernel write. It is done again only when the rootfs changes, not per kernel.

### 4.2 How `/init` finds and mounts ROOT

- **Use `kern_guid`, not `root=`.** depthcharge already replaces `%U` in the stored `kern_guid=%U` with KERN-A's
  PARTUUID ([fit-packaging.md](fit-packaging.md) section 3). The kernel's own `root=PARTUUID=%U/PARTNROFF=1` form only
  matters when the kernel mounts root itself, which it never does with an initramfs `/init`. So the command line and
  check 27's stored-line compare stay unchanged.
- **The lookup is plain busybox.** At the pin, `part_uevent` exports `PARTN`, `PARTNAME` and `PARTUUID`
  (`block/partitions/core.c:258-262`). `/init` waits for USB storage (as its USB stage already does, up to 20 s), finds
  the `/sys/class/block/*/uevent` whose `PARTUUID` equals `kern_guid`, takes its parent disk, and requires that
  disk's partition 2 to carry `PARTNAME=gbook-root`.
- **Mount and hand off:**
  1. `fsck` is optional (e2fsprogs is not in the initramfs). The ext4 journal covers an unclean stop.
  2. Mount ROOT read-write on `/newroot`, mount a tmpfs on `/newroot/run`, and copy the hand-off files there (4.3).
  3. Move `/dev`, `/proc` and `/sys` over, then `exec switch_root /newroot /sbin/init`.
- **Fallback:** no ROOT (or a failed mount) within the USB wait runs today's path unchanged: captures, netlog, reboot.
  A broken rootfs still yields a netlog.

### 4.3 What stays in the initramfs

- **Everything that probes before root:** busybox, `/init`, `iw`/`wpa_supplicant` and the whole staged firmware tree.
  Built-in drivers load firmware at probe time (ath12k, the ADSP and CDSP remoteprocs), before ROOT can be mounted.
- **Copied into the new root's `/run`, never into the rootfs image:**
  - `/run/gbook/gbook.log`: the `GBOOK:` lines so far (`switch_root` frees the initramfs);
  - `/run/gbook/wpa_supplicant.conf`, mode 600: the owner's network block, as `/init` handles it today;
  - `/run/gbook/firmware/`: the stock `qcom/x1e80100/google/mica/` files only, for a remoteproc restart after the
    hand-off. `/init` writes that path to `/sys/module/firmware_class/parameters/path` before `switch_root`
    (`fw_search_path.rst`).
  - The rootfs then holds only redistributable firmware, from Debian's `firmware-qcom-soc` and `firmware-atheros`
    20260916-1. The latter carries `ath12k/WCN7850/hw2.0/{amss,m3,board-2}.bin` and `qca/hmtbtfw20.tlv`
    (packages.debian.org file list, read 2026-11-04).
- **Two to verify on the first rootfs boot:** that firmware lookups after `switch_root` resolve against the new root
  (`kernel_read_file_from_path_initns` opens the path under the init task's filesystem, `fs/kernel_read_file.c:147-166`;
  not traced further), and that the GPU's first open in userspace loads `gen70500_*` from the rootfs.
- **The rootfs image stays shareable:** no Wi-Fi secret, no stock blob, no per-unit identifier. That is what
  [ADR 0011](../adr/0011-versions-and-releases.md)'s "image leaves the build host" case needs.

### 4.4 Showing the M3 criteria

A `gbook-m3.service` in the rootfs runs once after `network-online.target`. It prints `GBOOK:` lines to `/dev/console`
(the AP console, still read-only to us) and appends them to the netlog. Its checks:
- **Mesa on the GPU:**
  - `eglinfo -B` names "Adreno X1-85" and freedreno; `vulkaninfo --summary` names Turnip.
  - `kmscube` (or `glmark2-es2-drm`) on `card2` proves the kmsro path, and the owner sees it on the panel.
  - Then `cage` runs Ghostty as an unprivileged user, a real OpenGL 4.3 app on the panel.
  - Capture `GL_RENDERER`, the GL version and any GPU fault lines from dmesg.
- **Wi-Fi in userspace:**
  - `wpa_supplicant@wlan0` reads `/run/gbook/wpa_supplicant.conf` through a unit drop-in (*inference*: the stock
    unit reads a file under `/etc/wpa_supplicant/`), and `systemd-networkd` takes DHCP.
  - Debian sid has every tool named here (madison, read 2026-11-04): `mesa-utils` and `mesa-utils-bin` 9.0.0-2+b3
    (`eglinfo`), `vulkan-tools` 1.4.341.0, `kmscube` 0.0.0~git20260822-1, `glmark2` 2023.01, `cage` 0.3.1-1 and
    `wpasupplicant` 2:2.11-7.
  - Proof: `networkctl status wlan0` (redacted), `iw dev wlan0 link` (signal and frequency only), a gateway ping, and
    the netlog itself sent over that link from userspace.
- **Audio state known:** the [status](../status.md) rows read "no sound node in the DTS".
  - Minimum: record what `aplay -l` shows (expected: no card) as the known state.
  - Better: one diagnostic attempt with the 9345's sound node as a `dts/diag/*.dtsi` (marked unverified per
    [ADR 0004](../adr/0004-device-tree-from-9345.md)), a `kernel/mica-audio.config` building `SND_SOC_X1E80100`,
    `SND_SOC_WSA884X`, the LPASS macros, `SOUNDWIRE_QCOM`, `QCOM_APR` and `SND_SOC_QDSP6` in (all `=m` today), and
    Debian's 9345 topology and UCM.
  - mica's stock ADSP image may not match the 9345's topology, so either outcome counts as "known".
- **No listener, no getty on the AP console:** mask `serial-getty@ttyMSM0` ([ADR 0006](../adr/0006-debug-console-ccd-suzyq.md);
  `/init` has "No interactive shell"). Install no `sshd`; today's `/init` says "Nothing listens on the network". A getty
  or an autologin session on the panel (`tty1`) is the owner's to allow.

### 4.5 Keeping the attempt and netlog tooling

- **What the tooling parses:** `watch`, `follow` and `compare` read `GBOOK:` lines; `boot_health.py` and `tally` read
  the netlog's dmesg and SCMI trace sections; `image-check` compares the booted kernel with the verified stick.
- **One sender for both:** move `/init`'s netlog block (`redact`, sections, `--- end of netlog`) into one script in
  `kernel/initramfs/`, used by `/init` and shipped into the rootfs. Same format, same listener
  (`attempt.sh netlog start`).
- **The rootfs sends after its checks and then stays up.** A base image cannot depend on a `gbook.*` debug argument
  ([ADR 0011](../adr/0011-versions-and-releases.md)), and an M3 release is a usable system, not a capture-and-reboot.
  Test rootfs builds may reboot like today.
- **Release identity:** a release names two artifacts. *Inference/proposal:* the tag message adds the rootfs image's
  sha256, the snapshot timestamp and the lock file's hash, next to the KERN-A image hash `attempt.sh stick` prints.

### 4.6 Kernel-side follow-ups

- `kernel/mica-rootfs.config`: `# CONFIG_FW_LOADER_USER_HELPER is not set` (systemd README). `USB_UAS=y` is optional.
- `kernel/mica-audio.config` for the audio attempt above.
- Omarchy's `linux-omarchy-aarch64` patches 2002 and 2003 are kernel patches, not Mesa or rootfs patches (README
  "Resume here" lists "a rootfs with Mesa" as a lead; a handoff paired it with them).
  - `2002-power-supply-qcom_battmgr-Notify-charger-supplies-of-online-changes.patch` (Brandon Williams, 2026-10-13):
    without it "UPower keeps the state it read at startup".
  - `2003-wifi-ath12k-don-t-count-a-vdev-restart-as-a-started-.patch` (Birk Skyum, 2026-10-20): stops 3 s
    `time out while waiting for fw stats done` stalls after an AP changes channel or bandwidth.
  - Both matter once UPower and a long-lived Wi-Fi link exist. They would enter as `kernel/patches/` with status lines
    ([ADR 0007](../adr/0007-local-kernel-patches.md)). Their upstream status was not checked.

### 4.7 Steps

1. Measure: an `mmdebstrap --simulate` (or `apt-get install --dry-run`) of the package list in the container, to size
   the rootfs and to choose `D` for the owner's stick.
2. `scripts/build-rootfs.sh`: snapshot pin, lock list, `.deb` cache, `SOURCE_DATE_EPOCH`, ext4 output, a manifest with
   sha256. It runs through `pkexec docker run` with the extra capability.
3. `package-in-container.sh`: the two-entry GPT (4.1); `/init`'s ROOT lookup and hand-off (4.2-4.3); the shared netlog
   sender; a check in `scripts/check.sh` for the lookup against synthetic uevent files.
4. Owner: write ROOT once, then attempts as today. First boot: `eglinfo` and `kmscube`, then Wi-Fi, then Ghostty, then
   audio.
5. An ADR for the rootfs choice and the boot design, once the owner answers section 5.

## 5. Open questions for the owner

Reply in the usual form ("1a 2 ok"); each has a recommended answer.

1. **Distribution for M3.** a) Debian sid arm64 via `mmdebstrap`, snapshot-pinned, in the existing container;
   b) Arch Linux ARM + Omarchy's aarch64 repo now (Ghostty 1.4.0 binary, no dated pin); c) Ubuntu 26.10;
   d) postmarketOS. *Recommended: a*, with b reconsidered for M4.
2. **Ghostty at M3.** a) build 1.4.0 from the minisign-checked tarball with Zig 0.17 in the container (first-party
   sources, build time unmeasured); b) the community 1.3.1 arm64 `.deb` (fast, third-party binary, not in a release
   image); c) none until M4, with `kmscube`/`glmark2` as the GL proof. *Recommended: a*, falling back to c if the
   emulated build proves impractical.
3. **Stick layout.** a) ROOT as partition 2 on the same stick from 256 MiB, declared in every image's GPT, so the
   per-attempt `dd` is unchanged; b) a second stick through a hub. *Recommended: a.*
4. **Finding ROOT.** a) `/init` matches `kern_guid` to a `PARTUUID` and mounts partition 2 labelled `gbook-root` on the
   same disk; b) a fixed `root=PARTUUID=…` of ROOT on the command line. *Recommended: a* (no stick-specific value in
   the image, command line unchanged).
5. **Secrets and vendor firmware.** a) the Wi-Fi block and the stock ADSP/CDSP files stay in the initramfs and are
   copied to the new root's `/run`; the rootfs carries only redistributable firmware; b) put both into the rootfs image
   (it then never leaves the build host). *Recommended: a.*
6. **Modules.** a) keep everything built in, adding `mica-rootfs.config` and `mica-audio.config`; b) ship
   `/lib/modules` in the rootfs (stale after each kernel-only rewrite). *Recommended: a.*
7. **Audio for M3.** a) one diagnostic attempt with the 9345 sound node, `mica-audio.config` and Debian's 9345
   topology and UCM, recording whatever happens; b) record "no sound node" as the known state. *Recommended: a.*
8. **Console and network policy.** a) mask `serial-getty@ttyMSM0`, no `sshd`, nothing listening; an autologin `cage`
   session with Ghostty on the panel only; b) also a getty on `tty1`. *Recommended: a.*
9. **Container capability.** a) let `build-rootfs.sh` run its container with `--cap-add SYS_ADMIN` (mmdebstrap's root
   mode mounts); b) try `--mode=unshare` or `fakechroot` without it first. *Recommended: b, then a* if it fails.
10. **Release identity.** a) an M3 tag message also names the rootfs sha256, snapshot timestamp and lock hash (an
    [ADR 0011](../adr/0011-versions-and-releases.md) update); b) tag the kernel image only. *Recommended: a.*

## Sources

| Source | Ref | Commit or version | Read |
|---|---|---|---|
| omacom/omarchy-pkgs | `master` | `66368e24e900bef4baa6d136c1254bc66daaef0d` | 2026-11-04 |
| omacom/omarchy | `quattro` | `84b3f2872b5023c13967543ed4a98b08fcac5b21` | 2026-11-04 |
| Mesa (gitlab.freedesktop.org API) | `main`; tags `mesa-24.2.0`, `mesa-24.3.0`, `mesa-26.0.0`, `mesa-26.2.0` | `32f5c9344041e53c3bff89c6fc5b107c8b7ed471` | 2026-11-04 |
| Ghostty | tag `v1.4.0` | tag object `ce787fc18a7782e81585beb63f0d905ccaf69284` | 2026-11-04 |
| systemd | tag `v262`, `README` | tag | 2026-11-04 |
| alsa-ucm-conf | tag `v1.2.16.1` | tag | 2026-11-04 |
| Linux | torvalds | `a804c5742bff` (local tree, patches applied outside `block/`, `fs/`, `init/`) | 2026-11-04 |
| vboot_reference | `firmware-bluey-16702.B` | `34fbbe62cc18` (cached in `.firecrawl/`) | 2026-11-04 |

Package indexes, all read 2026-11-04:
- Debian: `https://qa.debian.org/madison.php`, `https://packages.debian.org/sid/all/firmware-qcom-soc/filelist`,
  `https://sources.debian.org/api/src/ghostty/` (404).
- Ubuntu: `https://people.canonical.com/~ubuntu-archive/madison.cgi`, `https://api.launchpad.net/devel/ubuntu/series`,
  `http://ports.ubuntu.com/ubuntu-ports/dists/resolute/Release`.
- Fedora: `https://mdapi.fedoraproject.org/<release>/srcpkg/<name>`, `https://bodhi.fedoraproject.org/releases/`.
- Alpine edge: `https://dl-cdn.alpinelinux.org/alpine/edge/{main,community,testing}/aarch64/APKINDEX.tar.gz`.
- Arch Linux ARM: `http://mirror.archlinuxarm.org/aarch64/{core,extra}/*.db`.
- Omarchy: `https://pkgs.omarchy.org/stable/aarch64/omarchy.db`,
  `https://arm-stable-mirror.omarchy.org/aarch64/extra/extra.db`.
- Pages: ghostty.org `docs/linux`, `docs/install/binary`, `docs/install/build`; docs.mesa3d.org `drivers/freedreno.html`;
  manpages.debian.org `mmdebstrap(1)` (1.6.0-5); snapshot.debian.org; snapshot.ubuntu.com;
  discourse.ubuntu.com `t/48800`; fedoraproject.org wiki `Snapdragon_WoA_Laptop_Install`;
  github.com/mkasberg/ghostty-ubuntu releases.
- Local reads on the build host: `/proc/sys/fs/binfmt_misc/qemu-aarch64`; `~/.cache/gbook/build-a804c57/.config`.

## Not found

- A Ghostty package in Debian (any suite) or Fedora; a Ghostty arm64 binary of 1.4 anywhere but Omarchy's repo.
- A dated archive for Arch Linux ARM or Alpine edge; a confirmed snapshot service for Ubuntu ports (arm64).
- Whether snapshot.debian.org serves `non-free-firmware` for sid: the service answered 503/504 on 2026-11-04.
- The Zig version for Ghostty 1.4 on ghostty.org (its table stops at 1.3.x); the 0.17 figure is from Omarchy's PKGBUILD.
- Whether vboot writes a repaired backup GPT back to the stick (`gpt_misc.c` not read).
- The rootfs size; the build time of Ghostty under qemu-user; whether mmdebstrap runs without `CAP_SYS_ADMIN` in the
  container.
- The upstream status of Omarchy patches 2002 and 2003; whether mica's speaker path matches the 9345's.
- A current postmarketOS page on its edge base (wiki.nura.eco served a bot check).
