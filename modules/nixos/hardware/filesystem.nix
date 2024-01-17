{ lib, config, ... }:
let
  cfg = config.modules.hardware.fileSystem;
in
{
  boot = {
    loader.systemd-boot = {
      enable = true;
      consoleMode = "auto";
      configurationLimit = 10;
    };
    # Faster but also needed for build-vm to work with impermanence
    initrd.systemd.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "zfs" ];
  };

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
