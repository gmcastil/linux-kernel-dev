SHELL		:= /bin/bash

VM_DIR		:= vm

PHONY: initramfs

initramfs:
	$(MAKE) -C $(VM_DIR) initramfs

