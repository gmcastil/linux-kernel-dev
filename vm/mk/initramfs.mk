INITRAMFS	:= initramfs.cpio.gz

.PHONY: initramfs

$(INITRAMFS): $(ROOTFS_STAGED_STAMP)

initramfs: $(INITRAMFS)
	fakeroot $(VM_SCRIPTS_DIR)/build-initramfs $(ROOTFS_DIR) $(INITRAMFS)

initramfs-clean:
	rm -f $(INITRAMFS)

