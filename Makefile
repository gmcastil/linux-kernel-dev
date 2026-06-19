SHELL		:= /bin/bash

VM_DIR		:= vm

.PHONY: clean initramfs

initramfs:
	$(MAKE) -C $(VM_DIR) initramfs

clean:
	$(MAKE) -C $(VM_DIR) clean
	rm -rf linux-*

