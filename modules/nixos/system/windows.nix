{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    mkEnableOption
    mkOption
    types
    optional
    ;
  inherit (config.${ns}.hardware) secure-boot;
  inherit (cfg.bootEntry) fsAlias;
in
[
  {
    guardType = "custom";

    opts.bootEntry = {
      enable = mkEnableOption "Windows systemd-boot boot entry";

      fsAlias = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The fs alias of the windows partition";
      };
    };
  }

  (mkIf cfg.enable {
    # Enable mounting windows ntfs drive
    boot.supportedFilesystems.ntfs = true;
  })

  (mkIf cfg.bootEntry.enable {
    warnings =
      optional (fsAlias == null) ''
        The Windows fs alias is not set. The Windows boot entry will NOT work
        and the insecure edk2 shell will be enabled.
      ''
      ++ optional (secure-boot.enable && cfg.bootEntry.enable) ''
        You have enabled secure boot and the Windows boot entry. It is not
        recommended to use both as manually signing the edk2 shell reduces the
        security of secure boot and the declarative systemd-boot config for the
        windows boot options might not work as lanzaboote overrides it.
      '';

    # How to get the fs alias:
    # 1. Run `sudo blkid | grep vfat` and take note of the PARTUUID of the Windows 'EFI system partition'
    # 2. Make sure cfg.fsAlias is null and reboot into edk2-shell
    # 3. Take note of the fs alias starting with HD... for matching PARTUUID
    # 4. Set bootEntry.fsAlias to the alias and disable bootEntry.bootstrap

    # Detailed instructions:
    # https://forum.endeavouros.com/t/tutorial-add-a-systemd-boot-loader-menu-entry-for-a-windows-installation-using-a-separate-esp-partition/37431
    # https://archive.is/wwZaP

    # There's also this resource: https://nixos.org/manual/nixos/unstable/options#opt-boot.loader.systemd-boot.windows._name_.efiDeviceHandle
    boot.loader.systemd-boot = {
      edk2-uefi-shell.enable = fsAlias == null;

      windows."windows" = mkIf (fsAlias != null) {
        title = "Windows";
        efiDeviceHandle = mkIf (fsAlias != null) fsAlias;
        sortKey = "0"; # place above NixOS entries
      };
    };

    ns.userPackages = optional (fsAlias != null) (
      pkgs.makeDesktopItem {
        name = "boot-windows";
        desktopName = "Boot Windows";
        type = "Application";
        exec = "systemctl reboot --boot-loader-entry=windows_windows.conf";
        icon = "computer";
        categories = [ "System" ];
      }
    );

    programs.zsh.shellAliases = mkIf (fsAlias != null) {
      boot-windows = "systemctl reboot --boot-loader-entry=windows_windows.conf";
    };
  })
]
