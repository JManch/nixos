{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf utils;
  cfg = config.modules.hardware.fileSystem;
in
{
  assertions = utils.asserts [
    (cfg.tmpfsTmp -> !config.modules.system.impermanence.enable)
    "Tmp on tmpfs should not be necessary if impermanence is enabled"
  ];

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
    tmp.useTmpfs = cfg.tmpfsTmp;

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

  services.zfs = {
    trim.enable = cfg.trim;
    autoScrub.enable = true;
  };

  programs.zsh.shellAliases = {
    boot-bios = "systemctl reboot --firmware-setup";
  };
}
