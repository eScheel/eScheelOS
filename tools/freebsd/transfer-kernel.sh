#!/usr/local/bin/bash

VBOX_DIR="/home/jscheel/VirtualBox VMs/eScheelOS"
BUILD_DIR="/home/jscheel/Github/eScheelOS/build"

echo ""
echo "--------------------------------"
echo " Attaching device $VBOX_DIR/eScheelOS.vhd"
echo "--------------------------------"
sudo mdconfig -a -t vnode -f "$VBOX_DIR/eScheelOS.vhd" -u 0

echo ""
echo "--------------------------------"
echo "Copying $BUILD_DIR/kernel.elf to /dev/md0s1"
echo "--------------------------------"
sudo mcopy -i /dev/md0s1 "$BUILD_DIR/kernel.elf" ::/

echo ""
echo "--------------------------------"
echo "Detaching."
echo "--------------------------------"
sudo mdconfig -d -u 0