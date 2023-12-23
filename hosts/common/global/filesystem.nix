{
  boot = {
    loader.systemd-boot = {
      enable = true;
      consoleMode = "auto";
    };
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = ["zfs"];
  };

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = ["size=4G" "mode=755"]; # only root can write to these files
    };

    "/nix" = {
      device = "zpool/nix";
      fsType = "zfs";
    };

    "/persist" = {
      device = "zpool/persist";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = ["umask=0077" "defaults"];
    };
  };

  swapDevices = [];
  zramSwap.enable = true;

  systemd.services.zfs-mount.enable = false;
  services.zfs = {
    trim.enable = true;
    autoScrub.enable = true;
  };

  programs.zsh.shellAliases = {
    bootbios = "systemctl reboot --firmware-setup";
  };
}
