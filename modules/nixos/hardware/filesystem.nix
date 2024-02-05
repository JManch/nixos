{ lib, config, ... }:
let
  cfg = config.modules.hardware.fileSystem;
in
{
  boot = {
    loader.systemd-boot = {
      enable = true;
      consoleMode = "auto";
      configurationLimit = 20;
    };

    # Faster but also needed for build-vm to work with impermanence
    initrd.systemd.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # ZFS does not necessarily support the latest kernel
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    supportedFilesystems = [ "zfs" ];

    # To get kernel 6.7 support until zfs 2.2.3 is released https://github.com/openzfs/zfs/pull/15836
    zfs.enableUnstable = true;
  };

  # TODO: Enable ZFS zfs.autoSnapshot at an infrequent interval (maybe once a
  # week?) in addition to zfs.autoReplication to backup onto my home server?
  # Requirements
  # - Finish home server nix config
  # - Create a seperate zfs dataset for .local/share/Steam so games don't bloat snapshots

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "defaults"
        "mode=755"
      ] ++ lib.lists.optional (cfg.rootTmpfsSize != null) "size=${cfg.rootTmpfsSize}";
    };

    "/nix" = {
      device = "${cfg.zpoolName}/nix";
      fsType = "zfs";
    };

    "/persist" = {
      device = "${cfg.zpoolName}/persist";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/boot" = {
      device = "/dev/disk/by-label/${cfg.bootLabel}";
      fsType = "vfat";
      options = [ "defaults" "umask=0077" ];
    };
  };

  swapDevices = [ ];
  zramSwap.enable = true;

  systemd.services.zfs-mount.enable = false;
  services.zfs = {
    trim.enable = cfg.trim;
    autoScrub.enable = true;
  };

  programs.zsh.shellAliases = {
    boot-bios = "systemctl reboot --firmware-setup";
  };
}
