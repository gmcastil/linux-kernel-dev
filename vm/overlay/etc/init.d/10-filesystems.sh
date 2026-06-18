#!/bin/sh

. /etc/init.d/functions.sh

# Mount virtual filesystems before we get started
action "Mounting /proc" sh -c 'mount -t proc proc /proc'
action "Mounting /sys" sh -c 'mount -t sysfs sysfs /sys'
action "Mounting /dev" sh -c 'mount -t devtmpfs devtmpfs /dev'

