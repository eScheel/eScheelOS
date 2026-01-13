#!/bin/bash

# Adjust path if necessary
VHD_PATH="/mnt/c/Users/jscheel/VirtualBox VMs/eScheelOS/eScheelOS.vhd"
if [ ! -f "$VHD_PATH" ]; then
    echo "Error: VHD file not found at $VHD_PATH"
    exit 1
fi

echo ""
echo "--------------------------------"
echo "Erasing $VHD_PATH"
echo "--------------------------------"
dd if=/dev/zero of="$VHD_PATH" bs=512 count=4949274 conv=notrunc status=progress

echo ""
echo "--------------------------------"
echo "Attaching loopback device."
echo "--------------------------------"
LOOP_DEV=$(sudo losetup -fP --show "$VHD_PATH")
if [ -z "$LOOP_DEV" ]; then
    echo "Error: Failed to setup loop device."
    exit 1
fi

echo ""
echo "--------------------------------"
echo "Creating Fat32 partition."
echo "--------------------------------"
# Using sfdisk to write MBR safely without touching the footer
# 0x0C = FAT32 LBA, * = Bootable
sudo sfdisk "$LOOP_DEV" <<EOF
63,4917535,0c,*
EOF

# Force kernel to re-read partition table
sudo partprobe "$LOOP_DEV"
sleep 1

echo ""
echo "--------------------------------"
echo "Formatting Fat32 partition."
echo "--------------------------------"
PART_DEV="${LOOP_DEV}p1"
if [ ! -e "$PART_DEV" ]; then
    echo "Error: Partition device $PART_DEV not found."
    sudo losetup -d "$LOOP_DEV"
    exit 1
fi
# Format as FAT32
# -h 63 : Hidden sectors (Matches partition start)
# -s 64 : Sectors per cluster
# -R 32 : Reserved sectors
sudo mkfs.vfat -F 32 -R 32 -s 64 -S 512 -h 63 -M 0xf8  "${LOOP_DEV}p1"
sudo sync

echo ""
echo "--------------------------------"
echo "Detaching."
echo "--------------------------------"
sudo losetup -d "$LOOP_DEV"

echo "Done."