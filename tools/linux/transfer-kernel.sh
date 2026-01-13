#!/bin/bash

# Adjust this path if necessary
MOUNT_DIR="/mnt/osdev"
BUILD_DIR="/mnt/c/Users/jscheel/Github/eScheelOS/build"
VHD_PATH="/mnt/c/Users/jscheel/VirtualBox VMs/eScheelOS/eScheelOS.vhd"
KERNEL_BIN="$BUILD_DIR/kernel.elf"
if [ ! -f "$KERNEL_BIN" ]; then
    echo "Error: $KERNEL_BIN not found. Did you run 'make kernel'?"
    exit 1
fi

echo ""
echo "--------------------------------"
echo "Attaching loopback device."
echo "--------------------------------"
# -P forces partition scanning
LOOP_DEV=$(sudo losetup -fP --show "$VHD_PATH")
if [ -z "$LOOP_DEV" ]; then
    echo "Error: Failed to setup loop device."
    exit 1
fi

# Use p1 for the first partition
PART_DEV="${LOOP_DEV}p1"
# Wait for partition device to appear
sleep 1
if [ ! -e "$PART_DEV" ]; then
    echo "Error: Partition device $PART_DEV not found."
    sudo losetup -d "$LOOP_DEV"
    exit 1
fi

echo ""
echo "--------------------------------"
echo "Mounting loopback device to $MOUNT_DIR."
echo "--------------------------------"
if ! sudo mount -t vfat "$PART_DEV" "$MOUNT_DIR"; then
    echo "Error: Mount failed. The drive might not be formatted correctly or mount folder doesn't exist."
    sudo losetup -d "$LOOP_DEV"
    exit 1
fi

echo ""
echo "--------------------------------"
echo "Transferring the kernel."
echo "--------------------------------"
echo "Transferring kernel..."
if sudo cp "$KERNEL_BIN" "$MOUNT_DIR/"; then
    echo "Kernel copied successfully."
else
    echo "Error: Failed to copy kernel."
fi
# Verify file is physically there
if [ ! -f "$MOUNT_DIR/kernel.elf" ]; then
    echo "Warning: Kernel file check failed!"
fi

echo ""
echo "--------------------------------"
echo "Unmounting and Detaching."
echo "--------------------------------"
sudo umount "$MOUNT_DIR"
sudo losetup -d "$LOOP_DEV"

echo "Done."