# 5. Vendor content and per-unit identifiers stay out of git; extraction stays reproducible

## Status

Accepted 2026-10-21. It records rules that `CLAUDE.md` has applied since the scaffold.

## Context

- **Vendor blobs:** the work needs Google's and Dell's binaries (the recovery image, the stock DTB, and the DSP
  and GPU firmware), and they are not ours to redistribute.
- **Identifiers:** recon output is meant for public channels (#aarch64-laptops, linux-arm-msm), but adb, the GSC
  and the recovery image all expose per-unit identifiers (serials, chip IDs, MACs, pcr0).
- **Remote:** the repo is private on the private remote today and may become public.

## Decision

- **`dumps/` is gitignored.** It holds downloads and extractions (recovery zip and image, partitions, stock
  DTBs, firmware). `*.img`, `*.bin`, `*.mbn`, `*.elf`, `*.dtb` and `.firecrawl/` are gitignored too.
- **Commit derived facts, not blobs:** hashes, sizes, node maps, addresses, keymaps as text, and source URLs.
- **Extraction is scripted** from public inputs (`scripts/extract-stock-dtb.sh` from the public recovery URL), so
  anyone can reproduce it.
- **Redaction happens before writing,** for anything committed: `scripts/recon.sh` redacts serial numbers, boot
  ids and MACs. GSC console captures leave out the Ti50 serial, chip ID and pcr0.

## Consequences

- A fresh clone cannot boot anything without running the extraction scripts first.
- Before any push, check: `git ls-files | rg '^dumps/'` must be empty, and no serial-like strings in `docs/`.

## Update 2026-11-05, 2:08 PM EST: the public export

The identifier list grows for publication (public-writeup.md, "Build round"; task #39).
LAN addresses are redacted at source like serials (commit `bf34583`: ADR 0012 and two recon notes). Host, user and remote
names and the owner's mail domain stay in this private repo's text and are substituted when `scripts/export-public.sh`
builds the public tree; that script holds the name list, and `site/gate.sh` (which ships with the export) holds only the
generic classes (MACs, serials, chip IDs, RFC 1918 addresses). Check 61 runs the export and the gate before every commit.
