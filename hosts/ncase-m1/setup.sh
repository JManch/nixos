#!/bin/sh
set -e # Abort on error

# Disk prompt
read -p "Enter install disk: " -r DISK
echo "Selected disk $DISK"
echo "WARNING: This will erase all data on disk $DISK"
read -p "Do you want to proceed? (y/n): " -n 1 -r
echo
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborting"
    exit 1
fi;
sleep .5
echo "Proceeding with install on disk $disk"
sleep 5


# Create partitions
echo "Creating disk partitions"
sleep 2
parted -s -a optimal $DISK \
    mklabel gpt \
    mkpart primary 0% 512MiB \
    mkpart primary 512MiB 100% \
    set 1 esp on

# Format UEFI partition
mkfs.fat -F 32 -n boot ${DISK}1

# Create ZFS pool
echo "Creating ZFS pool"
sleep 2
ZPOOL_ARGS=(
    -o ashift=12                # Use 4k sectors for performance
    -O atime=off                # Disable access time for performance
    -O mountpoint=none          # Disable automatic mounting
    -O xattr=sa                 # Improve performance of extended attributes
    -O acltype=posixacl         # Just needed
    -O encryption=aes-256-gcm
    -O keyformat=passphrase
    -O keylocation=prompt
    -O compression=lz4
    zpool
    ${DISK}2
)
zpool create "${ZPOOL_ARGS[@]}"

# Create ZFS datasets
echo "Creating ZFS datasets"
sleep 2
zfs create -o mountpoint=legacy zpool/nix
zfs create -o mountpoint=legacy zpool/persist

# Mount filesystems
echo "Mounting filesystems"
sleep 2
mkdir -p /mnt/{nix,boot,persist}
mount /dev/disk/by-label/boot /mnt/boot
mount -t zfs zpool/nix /mnt/nix
mount -t zfs zpool/persist /mnt/persist
mount -t tmpfs none /mnt
mount -t tmpfs none /mnt/home/joshua
