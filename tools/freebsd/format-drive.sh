#!/usr/local/bin/bash

VBOX_DIR="/home/jscheel/VirtualBox VMs/eScheelOS"

echo ""
echo "--------------------------------"
echo "Erasing $VBOX_DIR/eScheelOS.vhd"
echo "--------------------------------"
dd if=/dev/zero of="$VBOX_DIR/eScheelOS.vhd" bs=512 count=4949274 conv=notrunc status=progress

echo ""
echo "--------------------------------"
echo "Attaching loopback device."
echo "--------------------------------"
sudo mdconfig -a -t vnode -f "$VBOX_DIR/eScheelOS.vhd" -u 0

echo ""
echo "--------------------------------"
echo "Creating Fat32 partition."
echo "--------------------------------"
sudo gpart create -s mbr /dev/md0
sudo gpart add -t fat32 -b 63 -s 4917535 /dev/md0
sudo gpart set -a active -i 1 /dev/md0

echo ""
echo "--------------------------------"
echo "Formatting Fat32 partition."
echo "--------------------------------"
sudo newfs_msdos -F 32 -r 32 -S 512 -m 0xf8 -u 63 -o 63 -c 64 -s 4917535 /dev/md0s1

echo ""
echo "--------------------------------"
echo "Detaching."
echo "--------------------------------"
sudo mdconfig -d -u 0