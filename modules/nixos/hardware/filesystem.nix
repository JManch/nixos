{ lib
, pkgs
, config
, hostname
, ...
}:
let
  inherit (lib) optional mkIf;
  cfg = config.modules.hardware.fileSystem;
in
{
  # TODO: Set up SSD health monitoring with smartd or something
  # TODO: Enable ZFS zfs.autoSnapshot at an infrequent interval (maybe once a
  # week?) in addition to zfs.autoReplication to backup onto my home server?
  # Requirements
  # - Finish home server nix config
  # - Create a seperate zfs dataset for .local/share/Steam so games don't bloat snapshots
  # TODO: Use disko for filesystem setup

  zramSwap.enable = true;

  # We use legacy ZFS mountpoints and use systemd to mount them rather than
  # ZFS' auto-mount. Might want to switch to using the ZFS native mountpoints
  # and mounting with the zfs-mount-generator in the future.
  # https://github.com/NixOS/nixpkgs/issues/62644
  systemd.services.zfs-mount.enable = false;

  boot = {
    # Faster but also needed for build-vm to work with impermanence
    initrd.systemd.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # ZFS does not always support the latest kernel
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    zfs.package = mkIf cfg.unstableZfs pkgs.zfs_unstable;

    supportedFilesystems = [ "zfs" ];
    zfs.forceImportRoot = cfg.forceImportRoot;

    loader.timeout = mkIf cfg.extendedLoaderTimeout 30;
    loader.systemd-boot = {
      enable = true;
      editor = false;
      consoleMode = "auto";
      configurationLimit = 20;
    };
  };

  # This host hasn't been installed using disko
  # TODO: Eventually remove
  fileSystems = mkIf (hostname == "ncase-m1") {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "mode=755" ]
        ++ optional (cfg.rootTmpfsSize != null) "size=${cfg.rootTmpfsSize}";
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

  services.zfs = {
    trim.enable = cfg.trim;
    autoScrub.enable = true;
  };

  programs.zsh.shellAliases = {
    boot-bios = "systemctl reboot --firmware-setup";
  };
}
