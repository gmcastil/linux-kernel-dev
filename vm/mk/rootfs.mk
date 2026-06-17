ROOTFS_DIR		:= rootfs
ROOTFS_STAGED_STAMP	:= $(ROOTFS_DIR)/.rootfs.staged.stamp

.PHONY: rootfs

$(ROOTFS_STAGED_STAMP): $(BUSYBOX_BIN) $(INIT_DIR)/init $(wildcard $(INIT_DIR)/init.d/*)
	mkdir -p \
		$(ROOTFS_DIR)/bin \
		$(ROOTFS_DIR)/usr \
		$(ROOTFS_DIR)/proc \
		$(ROOTFS_DIR)/sys \
		$(ROOTFS_DIR)/dev \
		$(ROOTFS_DIR)/etc/init.d
	$(MAKE) -C $(BUSYBOX_DIR) CONFIG_PREFIX=$(abspath $(ROOTFS_DIR)) install
	# For an initramfs, we expect to find init in the root directory
	cp $(INIT_DIR)/init $(ROOTFS_DIR)/init
	chmod +x $(ROOTFS_DIR)/init
	# Copy the contents (using .) instead of shell globbing
	cp -av $(INIT_DIR)/init.d/. $(ROOTFS_DIR)/etc/init.d/
	chmod -R +x $(ROOTFS_DIR)/etc/init.d/.
	touch $@

rootfs: $(ROOTFS_STAGED_STAMP)

rootfs-clean:
	rm -f $(ROOTFS_STAGED_TAMP)
	rm -rf $(ROOTFS_DIR)
