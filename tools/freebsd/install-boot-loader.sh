#!/usr/local/bin/bash

VBOX_DIR="/home/jscheel/VirtualBox VMs/eScheelOS"
BUILD_DIR="/home/jscheel/Github/eScheelOS/build"

echo ""
echo "--------------------------------"
echo "Installing Mastor Boot Record."
echo "--------------------------------"
dd if="$BUILD_DIR/mbr.bin" of="$VBOX_DIR/eScheelOS.vhd" bs=446 conv=notrunc count=1

echo ""
echo "--------------------------------"
echo "Installing Volume Boot Record."
echo "--------------------------------"
dd if="$BUILD_DIR/vbr.bin" of="$VBOX_DIR/eScheelOS.vhd" bs=1 count=3 conv=notrunc seek=32256
dd if="$BUILD_DIR/vbr.bin" of="$VBOX_DIR/eScheelOS.vhd" bs=1 count=422 skip=90 conv=notrunc seek=32346

echo ""
echo "--------------------------------"
echo "Installing Stage2 Loader."
echo "--------------------------------"
dd if="$BUILD_DIR/stage2.bin" of="$VBOX_DIR/eScheelOS.vhd" bs=512 conv=notrunc seek=8