#!/bin/sh
set -e # Abort on error

# Check necessary extra programs are available
if ! command -v git &> /dev/null
then
    echo "git could not be found. Run inside 'nix-shell -p git bitwarden-cli' shell"
    exit 1
elif ! command -v bw &> /dev/null
then
    echo "bw could not be found. Run inside 'nix-shell -p git bitwarden-cli' shell"
    exit 1
fi

# Disk prompt
read -p "Enter install disk: " -r DISK
echo "WARNING: This will erase all data on disk '$DISK'"
read -p "Do you want to proceed? (y/n): " -n 1 -r
echo
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborting"
    exit 1
fi;

DISKPART=$DISK
if [[ "${DISK:5:4}" == "nvme" ]]; then DISKPART=${DISK}p; fi

# Host prompt
echo
HOST=""
while true; do
    read -p "Enter install host: " -r HOST
    if [ -d "$(dirname "$0")/hosts/$HOST" ]; then break; fi
    echo "Host '$HOST' does not exist"
done

# ZPOOL name prompt
echo
echo "WARNING: The zpool name must match modules.hardware.fileSystem.zpoolName in host config"
read -p "Enter zpool name: " -r ZPOOL
read -p "Are you sure you want to name the zpool '$ZPOOL'? (y/n): " -n 1 -r
echo
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborting"
    exit 1
fi;

# Boot label prompt
echo
echo "WARNING: The boot label must be unique on the device and must match modules.hardware.fileSystem.bootLabel in host config"
read -p "Enter boot label: " -r BOOTLABEL
read -p "Are you sure you want to label the boot partition '$BOOTLABEL'? (y/n): " -n 1 -r
echo
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborting"
    exit 1
fi;

printf "\n === Proceeding to install '$HOST' on '$DISK' with zpool '$ZPOOL' and boot label '$BOOTLABEL' === \n"
sleep 5

# Create partitions
printf "\n === Creating disk partitions === \n"
parted -s -a optimal $DISK \
    mklabel gpt \
    mkpart primary 0% 512MiB \
    mkpart primary 512MiB 100% \
    set 1 esp on

# Format UEFI partition
mkfs.fat -F 32 -n $BOOTLABEL ${DISKPART}1

# Create ZFS pool
printf "\n === Creating ZFS pool === \n"
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
    ${ZPOOL}
    ${DISKPART}2
)
zpool create "${ZPOOL_ARGS[@]}"

# Create ZFS datasets
printf "\n === Creating ZFS datasets === \n"
zfs create -o mountpoint=legacy ${ZPOOL}/nix
zfs create -o mountpoint=legacy ${ZPOOL}/persist

# Mount filesystems
printf "\n === Mounting filesystems === \n"
mount -t tmpfs none /mnt
mkdir -p /mnt/{nix,boot,persist}
mount -t zfs ${ZPOOL}/nix /mnt/nix
mount -t zfs ${ZPOOL}/persist /mnt/persist
mount -o umask=0077 /dev/disk/by-label/${BOOTLABEL} /mnt/boot

# Setup keys
printf "\n === Key Setup === \n"
mkdir -p /mnt/persist/etc/ssh
set +e
while true; do
    read -p "Enter bitwarden url code: " -r CODE
    OUTPUT=$(bw receive https://send.bitwarden.com/$CODE --output /mnt/persist/etc/ssh/ssh_host_ed25519_key)
    if [ "${OUTPUT:0:5}" == "Saved" ]; then break; fi
done
set -e
chmod 600 /mnt/persist/etc/ssh/ssh_host_ed25519_key
cp "$(dirname "$0")/hosts/$HOST/ssh_host_ed25519_key.pub" /mnt/persist/etc/ssh

# Install
mkdir -p /mnt/etc/nixos
git clone https://github.com/JManch/dotfiles /mnt/etc/nixos
nixos-install --no-root-passwd --flake /mnt/etc/nixos#$HOST
