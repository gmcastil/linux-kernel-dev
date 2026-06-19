BUSYBOX_DIR		:= busybox
BUSYBOX_DEFCONFIG	:= configs/busybox.defconfig
BUSYBOX_BIN		:= $(BUSYBOX_DIR)/busybox

BUSYBOX_URL		:= https://git.busybox.net/busybox
BUSYBOX_TAG		:= 1_37_stable
BUSYBOX_CLONE_STAMP	:= .busybox_clone_stamp

.PHONY: busybox

$(BUSYBOX_DIR)/.config: $(BUSYBOX_DEFCONFIG) $(BUSYBOX_CLONE_STAMP)
	cp $(BUSYBOX_DEFCONFIG) $(BUSYBOX_DIR)/.config

$(BUSYBOX_BIN): $(BUSYBOX_DIR)/.config
	$(MAKE) -C $(BUSYBOX_DIR) -j$(shell nproc)

$(BUSYBOX_CLONE_STAMP):
	git clone --depth 1 --branch $(BUSYBOX_TAG) $(BUSYBOX_URL) $(BUSYBOX_DIR)
	$(MAKE) -C $(BUSYBOX_DIR) distclean
	touch $@

busybox: $(BUSYBOX_BIN)

busybox-clean:
	rm -f $(BUSYBOX_CLONE_STAMP)
	rm -rf $(BUSYBOX_DIR)
