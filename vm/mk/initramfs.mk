INITRAMFS	:= initramfs.cpio.gz

.PHONY: initramfs

$(INITRAMFS): $(ROOTFS_STAGED_STAMP)
	cd $(ROOTFS_DIR) && find . | cpio -o -H newc | gzip -9 > ../$(INITRAMFS)

initramfs: $(INITRAMFS)

initramfs-clean:
	rm -f $(INITRAMFS)

