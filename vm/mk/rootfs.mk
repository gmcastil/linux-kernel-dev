ROOTFS_DIR		:= rootfs
ROOTFS_OVERLAY_DIR	:= overlay
ROOTFS_OVERLAY_FILES	:= $(shell find $(ROOTFS_OVERLAY_DIR) -type f)
ROOTFS_STAGED_STAMP	:= .rootfs.staged.stamp

.PHONY: rootfs

$(ROOTFS_STAGED_STAMP): $(BUSYBOX_BIN) $(ROOTFS_OVERLAY_FILES)
	rm -rf $(ROOTFS_DIR)
	cp -av $(ROOTFS_OVERLAY_DIR) $(ROOTFS_DIR)
	mkdir -p \
		$(ROOTFS_DIR)/bin \
		$(ROOTFS_DIR)/usr \
		$(ROOTFS_DIR)/proc \
		$(ROOTFS_DIR)/sys \
		$(ROOTFS_DIR)/dev
	# Install busybox components
	$(MAKE) -C $(BUSYBOX_DIR) CONFIG_PREFIX=$(abspath $(ROOTFS_DIR)) install
	# For now we just need the udhcp script from examples, later we
	# may need to addd the var_service for runit-style service supervision
	mkdir -p $(ROOTFS_DIR)/usr/share/udhcpc
	cp -v $(BUSYBOX_DIR)/examples/udhcp/simple.script $(ROOTFS_DIR)/usr/share/udhcpc/default.script
	# Make sureforeach some permissions are set properly
	chmod u+x $(ROOTFS_DIR)/init
	chmod -R u+x $(ROOTFS_DIR)/etc/init.d/[0-9]*
	touch $@

rootfs: $(ROOTFS_STAGED_STAMP)

rootfs-clean:
	rm -f $(ROOTFS_STAGED_STAMP)
	rm -rf $(ROOTFS_DIR)
