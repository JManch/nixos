{ config, ... }:
let
  cfg = config.modules.hardware.fileSystem;
in
{
  boot = {
    loader.systemd-boot = {
      enable = true;
      consoleMode = "auto";
    };
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "zfs" ];
  };

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "size=${cfg.rootTmpfsSize}" "mode=755" ];
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
      options = [ "umask=0077" "defaults" ];
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
    bootbios = "systemctl reboot --firmware-setup";
  };
}
