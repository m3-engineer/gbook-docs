# Start here

This site documents **gbook**: bringing mainline Linux up on the Dell XPS Googlebook, a Snapdragon X Elite (X1E80100)
ChromeOS laptop whose board name is **mica** (ChromeOS firmware branch `firmware-bluey-16702.B`). Everything here is
exported from the project's working repository at a release tag and rebuilt per release; the dates on each page are the
dates the facts were read or measured.

Two public ports exist for this machine. The [Nura](https://wiki.nura.eco/) (postmarketOS) port by Anton Bambura installs
through `pmbootstrap` and is the way to get a packaged system today. gbook builds its own kernel image for the ChromeOS
kernel partition and a Debian rootfs on a USB stick, and documents the parts the other record leaves open: the ChromeOS
boot path (depthcharge, FIT, EL2), the SCMI mailbox stall and the decision it led to, the sound card's SoundWire wake
fix, and a status matrix with a line of evidence for every row.

Where to look:

- [Status](docs/status.md): what works, where it works, what is upstream, with evidence for every row.
- The guide: [How mica boots Linux](how-mica-boots.md), [SCMI over the CPUCP mailbox](scmi-cpucp.md),
  [Sound on mica](sound.md), [the device tree compared with the Nura port](device-tree-compared.md).
- How-to: [Boot a gbook image](how-to-boot.md), with the recovery steps first.
- Reference: [Device tree](dts/README.md), [Local patches](kernel/patches/README.md), [Kernel configuration](kernel/README.md),
  [Glossary](CONTEXT.md), [Releases](releases.md).
- [Decisions](docs/adr/README.md), [Research](docs/research/README.md) and [Evidence](docs/recon/README.md): the records
  behind the claims.

There is no image to download yet: the recipes are documented and the public repository holds no binaries. The two
released images so far are described on the Releases page by their tag messages.

Nothing on this site has been sent upstream. The project holds its kernel and device-tree submissions until its
milestone M5 (decision 0010); four local patches are listed by their status lines only until then.

**A warning:** this is experimental work on a device whose firmware can refuse to boot an unsigned image or need a
recovery stick to return to stock. Read the recovery decisions (0001, 0002) before touching developer mode.

Licence: prose CC BY-SA 4.0, tooling MIT, device tree BSD-3-Clause, patches GPL-2.0-only ([details](licence.md)).
