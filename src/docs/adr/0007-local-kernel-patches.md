# 7. Local kernel patches live in kernel/patches/ and apply at build time

## Status

Accepted 2026-11-03 (owner, "1a 2a 3b").

## Context

- Until now the first-boot kernel was torvalds `a804c57` plus config fragments only (`kernel/*.config`).
- The first change that needs kernel source is a `panel-edp` entry for the mica panel (`LGD 0x0804`): without it the
  driver warns and uses fallback timings (`panel-edp.c:755-772`).
- The kernel tree lives outside the repo (`~/.cache/gbook/linux-a804c57`, set up by `scripts/setup-toolchain.sh`),
  and the DTS scripts and `check.sh` read the same tree.

## Decision

- **Patches are files in git:** `kernel/patches/NNNN-<topic>.patch`, unified diffs against the pinned commit, each
  with a header saying what it changes, its source and whether it went upstream. Name order is apply order.
- **`scripts/build-kernel.sh` applies them** before every build: it restores the files the patches touch from the
  pinned commit, fails if the tree has any other change, then runs `git apply` on each patch. The patches stay
  applied after the build, so the kernel release ends in `-dirty`.
- **`check.sh` check 20** fails when a patch no longer applies (or reverts) cleanly against the tree.
- **Upstream is a separate decision per patch.** The first one (`0001`, panel-edp) stays local: the EDID gives only
  part of the model name ("LP134WQ…"), and an upstream entry needs the full name.

## Consequences

- The pinned tree is no longer pristine after a build; `git -C ~/.cache/gbook/linux-a804c57 status` shows the patched
  files. Running `build-kernel.sh` again is safe, and any foreign edit stops it.
- Moving the pin (ADR 0004) means re-checking every patch; check 20 shows which ones break.

## Update 2026-11-04 (10:07 AM ET): a status line on every patch, and numbers are never reused

Owner: "all a" to question 5 of [milestones-versioning.md](../research/milestones-versioning.md), section 5.
- **Line 1 of every patch** reads `Status: <WORD> <reference>`. The words are ChromiumOS's patch-tagging words, with
  `LOCAL` in place of its `CHROMIUM` and no `BACKPORT` (a modified copy says so in its reference):
  - `LOCAL <who>`: carried downstream and not posted to a list (gbook's own, or a third party's downstream fix-up);
  - `FROMLIST <list reference>`: posted to a list, not in a maintainer tree when checked;
  - `FROMGIT <tree> <branch>`: in a maintainer or -next tree, not in mainline;
  - `UPSTREAM <tag or commit>`: in mainline, a backport onto the pin.

  A lore Message-ID goes in the reference when one is known, and the line says "not recorded" otherwise. The free-text
  header below the line stays. `git apply` ignores everything before the first diff, so check 20 is unaffected.
- **A patch number is never reused.** A deleted patch's number is retired, and the next patch takes the next unused
  number. Two numbers were reused before this rule:
  - `0008` first named a GENI I2C timing patch (`16a2828`) and now names the PCIe GDSC patch;
  - `0009` first named the IRQ-to-CPU-1 diagnostic (`cee735d`, deleted by [ADR 0009](0009-no-psci-cpuidle.md)) and
    now names the PCIe PHY GDSC patch.

  The new patches arrived on 2026-11-04 (`5272658` at 4:07 AM ET and `ddecbd8` at 4:47 AM ET). A log entry older
  than those commits that says "0008" or "0009" means the old patch.
- **`check.sh` check 34** enforces both rules. It allows exactly those two old reuses.
