SHELL		:= /bin/bash
VM_SCRIPTS_DIR	:= scripts

include mk/busybox.mk
include mk/rootfs.mk
include mk/initramfs.mk

vm-clean: busybox-clean rootfs-clean initramfs-clean

  # Target: busybox
  # Depends on: busybox source (clone/tarball)
  # Does: Builds the static busybox binary
  # ────────────────────────────────────────
  # Target: rootfs
  # Depends on: busybox, init/init, $(wildcard init/init.d/*)
  # Does: Stages the skeleton (bin/, sbin→bin, usr/bin→bin,
  #   usr/sbin→bin, proc/, sys/, dev/, etc/), drops the busybox
  #   binary into rootfs/bin/busybox, runs --install  -s, copies

  #   init/init → rootfs/init, copies init/init.d/* →
  #   rootfs/etc/init.d/
  # ────────────────────────────────────────
  # Target: initramfs.cpio.gz
  # Depends on: rootfs (and transitively everything under it)
  # Does: Packages the staged tree with cpio -o -H newc | gzip
  # ────────────────────────────────────────
  # Target: boot-stage1 (phony)
  # Depends on: bzImage only
  # Does: Calls run-qemu.sh with no initrd — smoke test, expect
  #   the VFS-mount panic
  # ────────────────────────────────────────
  # Target: boot (phony)
  # Depends on: bzImage, initramfs.cpio.gz
  # Does: Calls run-qemu.sh with the initrd attached — should
  #   land at your init system's shell
  # ────────────────────────────────────────
  # Target: clean (phony)
  # Depends on: —
  # Does: Removes rootfs/ and initramfs.cpio.gz — build output
  #   only, leaves busybox source/build tree alone




