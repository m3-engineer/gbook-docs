# Licence

```
gbook: mainline Linux on the Dell XPS Googlebook (mica)
Copyright (c) 2026 m3

This tree carries work under four licences. A file's path says which one applies; the texts are in LICENSES/.

1. Prose: every Markdown file and the site rendered from them.
   Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0): LICENSES/CC-BY-SA-4.0.txt.
   Attribution: "m3, gbook", with a link to this site.

2. Tooling: gate.sh, book.toml, the workflow under .github/, the kernel configuration fragments
   (src/kernel/*.config) and the build-script headers quoted under src/scripts/.
   The MIT License: LICENSES/MIT.txt.

3. Device tree sources (src/dts/*.dts, src/dts/*.fixups): BSD-3-Clause, as their SPDX headers state,
   with the copyright lines they carry (Qualcomm, Aleksandrs Vinarskis, and this project's additions).
   LICENSES/BSD-3-Clause.txt.

4. Kernel patches (src/kernel/patches/*.patch): GPL-2.0-only, as Linux kernel code. Each patch names
   its author; the FROMLIST ones are copies of patches posted to the kernel lists by their authors.
   LICENSES/GPL-2.0-only.txt.

Vendor firmware is not in this tree: src/kernel/firmware.sha256 lists hashes only.
```

Texts: [CC BY-SA 4.0](LICENSES/CC-BY-SA-4.0.txt), [MIT](LICENSES/MIT.txt), [BSD-3-Clause](LICENSES/BSD-3-Clause.txt), [GPL-2.0-only](LICENSES/GPL-2.0-only.txt).
