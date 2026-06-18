#!/bin/sh

. /etc/init.d/functions.sh

eth_dev='eth0'
udhcpc_script="/usr/share/udhcpc/default.script"

action "Bringing up interface ${eth_dev}" sh -c "ip link set ${eth_dev} up"
action "Determining IP information for ${eth_dev}" sh -c "udhcpc -i ${eth_dev} -s ${udhcpc_script}"

