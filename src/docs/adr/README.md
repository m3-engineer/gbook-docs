# Decisions

Architecture decision records, Nygard's shape (status, context, decision, consequences) with dated updates.

- [1. No bootloader unlock until a way back to stock is proven](0001-recovery-gates-unlock.md)
- [2. Experiment on a spare M.2 2230 SSD; keep the stock drive intact](0002-experiment-on-spare-ssd.md)
- [3. First boot through a ChromeOS kernel partition on external storage](0003-first-boot-chromeos-kernel-partition.md)
- [4. Mainline device tree forked from the XPS 13 9345; stock tree as hardware map only](0004-device-tree-from-9345.md)
- [5. Vendor content and per-unit identifiers stay out of git; extraction stays reproducible](0005-vendor-content-out-of-git.md)
- [6. Debug console through GSC CCD and a SuzyQ, read-only while CCD is locked](0006-debug-console-ccd-suzyq.md)
- [7. Local kernel patches live in kernel/patches/ and apply at build time](0007-local-kernel-patches.md)
- [8. The board DTS removes the PSCI domain idle states (cluster cl4/cl5, system ss3)](0008-no-psci-domain-idle-states.md)
- [9. No PSCI cpuidle on mica: the per-CPU domains lose `cluster_c4`](0009-no-psci-cpuidle.md)
- [10. Milestones M0 to M7, a feature status table, and the upstream hold ends at M5](0010-milestones-status-upstream-hold.md)
- [11. Versions: CalVer tags for released images, the gbook version in `uname -r`](0011-versions-and-releases.md)
- [12. M3 rootfs: Debian sid from a snapshot, on the stick's partition 2, entered by switch_root](0012-m3-rootfs-debian-sid.md)
- [Decisions](README.md)
