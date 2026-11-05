# 11. Versions: CalVer tags for released images, the gbook version in `uname -r`

## Status

Accepted 2026-11-04 (owner: "all a" to the open questions 2, 3, 4, 6 and 8 of
[milestones-versioning.md](../research/milestones-versioning.md), section 5). Question 5 (patch status lines) is an
update to [ADR 0007](0007-local-kernel-patches.md).

## Context

- Several things change at different rates: the repo (every commit), the boot image (every `package-image.sh`), the
  kernel base (a re-pin), the local patches, and the boots themselves. Each boot has an attempt ID `YYYY-MM-DD-N` in
  `attempts.tsv`. The repo has no tags. An image is identified only by its kernel banner (release plus UTS `#N`).
- SemVer requires a declared public API (semver.org 2.0.0, item 1), and gbook has none. CalVer suits projects whose
  releases are driven by external changes (calver.org, "When to use CalVer?"). Here those changes are the mainline
  base and the milestones.
- Annotated git tags "are meant for release" (`git-tag(1)`), and `git describe` reads only annotated tags by default.
- `scripts/setlocalversion` at the pin appends the contents of `localversion*` files in the object and source dirs to
  the release. `init/Kconfig` caps the release at 64 characters.
- The pin `a804c57` is a 7.4 merge-window commit, 1703 commits after `v7.3` and before `v7.4-rc1` (GitHub compare API,
  research note section 2).

## Decision

- **A release is a base image with 3 clean cold boots.** A base image has no debug command-line or DT extras
  (`scripts/attempt.sh stick` reads `base image`). The 3 boots of one image hash are counted by
  `scripts/attempt.sh tally`, and the image is one the owner would hand on. Every other image is an experiment, named
  only by its attempt IDs.
- **A release gets an annotated tag `vYYYY.0M.0D[.MICRO]`** (CalVer, e.g. `v2026.11.20`; `.1` for a second release
  the same day). The tag goes on the gbook commit that built the image, after its 3 boots. The image must have been
  built from a clean tree (no `+` in its `uname -r`). No SemVer.
- **The tag message is the release note** until a tagged image first leaves the build host. From then on, `CHANGELOG.md` in
  Keep a Changelog 1.1.0 form is the release note. The message contains:
  - the milestone;
  - the kernel base (`a804c57`, "v7.3 + 1703, 7.4 merge window") and the kernel release from `uname -r`;
  - each local patch with its status line;
  - the image sha256 as `scripts/attempt.sh stick` prints it;
  - the attempt IDs and the `tally` line that proved it;
  - what changed since the last tag.
- **`uname -r` names the gbook state.** `scripts/build-kernel.sh` writes `localversion-gbook` into the build directory
  (the `O=` dir, never the source tree). Its `gbook_localversion()` gives the exact rules, and check 35 tests them:
  - `-gbook-` plus `git describe` against the nearest annotated `v[0-9]*` tag, without the `v`
    (`-gbook-2026.11.20-3-g1a2b3c4`);
  - `-gbook-g<hash>` before the first tag;
  - a trailing `+` when the tree differs from the commit (changed tracked files, or untracked ones that are not
    ignored).

  Today that reads `7.3.0-gbook-g6934235-ga804c5742bff-dirty`. The kernel tree's own `-dirty` (the applied patches,
  ADR 0007) stays. A released image keeps the `-gbook-g<hash>` it was built with, because the tag comes after its
  boots. The tag message maps that hash to the version, and a rebuild at the tag would be a new, unproven image. The
  `kernel` column of `attempts.tsv` already records the release, so each attempt names its gbook commit, and no new
  column is needed.
- **Upstream series use the kernel's scheme only.** That means `[PATCH RFC]`, then `[PATCH vN]`, with the per-version
  changelog below `---` and `git format-patch --base` (`submitting-patches.rst` at the pin). A gbook version never
  appears in a patch subject.
- **The pin moves onto a mainline release tag.** The next re-pin is onto `v7.4` (or the release current then), after
  M3 and before M5 in any case ([ADR 0010](0010-milestones-status-upstream-hold.md)). After that, the pin moves at
  most once per mainline release. Each re-pin re-checks every local patch (check 20) and the DTS, and the first base
  image on the new pin needs its own 3 clean cold boots before it can be released.

## Consequences

- No tag exists on 2026-11-04. The image on the stick is a test image (`gbook.suspend=1 no_console_suspend`), and no
  base image with patches 0008 and 0009 has 3 clean cold boots yet.
- Every gbook commit changes the kernel release, so a rebuild relinks the version objects. The UTS `#N` keeps
  counting builds as before.
- The release grows by about 20 to 33 characters (worst case `-gbook-2026.11.04.1-12-g1234567+`), which stays under
  the 64-character cap.
- A tool to cut a release (check the tally, compose the tag message) is not needed until M3. It is left for then.
- Verified on 2026-11-04: build `#25` (kernel `Image` 52734464 bytes) reads `7.3.0-gbook-g8493ab4+-ga804c5742bff-dirty`
  in `include/config/kernel.release`, and `scripts/image_uts.sh` reads the same release from the `Image` banner. The `+`
  was an uncommitted log edit at build time.
- The `v7.4` re-pin replaces patches 0002 to 0007. Their series has a v2 (2026-10-30) that drops 0003 and adds four
  patches, and torvalds master's `cf27afc3bd6e` ("drm/msm: default separate_gpu_kms to auto selection") conflicts with
  0002, 0003 and 0005 to 0007 (patch-status lookup, 2026-11-04). The status lines of
  [ADR 0007](0007-local-kernel-patches.md)'s update record both.

## Update 2026-11-04 (2:03 PM ET): a release names the rootfs too

Owner, M3 round ("yes" to question 10 of [m3-rootfs.md](../research/m3-rootfs.md)). From M3 on, a release is two
artifacts: the KERN-A image and the rootfs image ([ADR 0012](0012-m3-rootfs-debian-sid.md)). The tag message adds
the rootfs image's sha256, its snapshot.debian.org timestamp and the hash of its lock list, next to the KERN-A image
hash that `scripts/attempt.sh stick` prints.

## Update 2026-11-04 (8:39 PM EST): the first release, `v2026.11.04`

Tagged by the owner from `scripts/release-draft.sh M3 '^2026-11-04-2[123]$'` at commit `506159b`: kernel
`7.3.0-gbook-g82c43ed-ga804c5742bff-dirty` (patches 0001 to 0009), KERN-A image `9673d6d782ef4cdb`, rootfs
`4b0e2e027c0b2d74…` from snapshot `20261104T000000Z` (lock `12f96fa08768262e…`, 321 packages), 3 clean cold boots.
Two things the first real run taught the tool: the Attempts line must come from `attempts.tsv` (tally lists every
id on one line), and `git log -n 40` rather than `| head`, which ended the script by SIGPIPE under pipefail before the
owner's tag line. The tag also records the rootfs read back from the stick (`attempt.sh root-verify`, retro-9/01):
`release-draft.sh` refuses a stick whose ROOT is not the manifest's rootfs.

## Update 2026-11-05 (9:54 AM EST): the second release, `v2026.11.05`

Tagged by the owner from `scripts/release-draft.sh M3 '^2026-11-05-5$'` at commit `69edd54`: kernel
`7.3.0-gbook-2026.11.04-35-g7c6a1aa-ga804c5742bff-dirty` (patches 0001 to 0011; the two new ones, 0010 and 0011, keep the four
speakers through the SoundWire masters' runtime PM wakes), KERN-A image `bc62c69ecf560525` (the sound node in the board DTS, no
extras), a rootfs from the same snapshot and lock as `v2026.11.04`'s (`20261104T000000Z`, lock `12f96fa08768262e…`, 321 packages),
rebuilt 2026-11-05 as `6fea12f2…` (the `audio` group, the `m3-swrm` capture; the udev rule tried that night never shipped), 3 clean cold boots (attempt `2026-11-05-5`), the four spoken channel names heard on each boot and the
microphones' capture heard played back. The AP console was absent for the three boots (the SuzyQ was unplugged on the build host's side);
the bar's evidence is the netlog, which `attempt.sh tally` reads. The draft ran once before the final docs commit and again on it,
so the tag file names the tagged commit: run it last.
