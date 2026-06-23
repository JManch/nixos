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
    mkForce
    ;
  inherit (config.${ns}.hardware) secure-boot;
  fsAliasConfigured = cfg.bootEntry.fsAlias != null || cfg.bootEntry.unstableFsAlias;
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

      unstableFsAlias = mkEnableOption ''
        a workaround for unstable fs alias that involves iterating through ESPs
        and booting the first Windows ESP we find.
      '';
    };
  }

  (mkIf cfg.enable {
    # Enable mounting windows ntfs drive
    boot.supportedFilesystems.ntfs = true;
  })

  (mkIf cfg.bootEntry.enable {
    warnings =
      optional (!fsAliasConfigured) ''
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
      edk2-uefi-shell.enable = !fsAliasConfigured;

      windows."windows" = mkIf fsAliasConfigured {
        title = "Windows";
        efiDeviceHandle = cfg.bootEntry.fsAlias;
        sortKey = "0"; # place above NixOS entries
      };

      extraEntries."windows_windows.conf" = mkIf cfg.bootEntry.unstableFsAlias (mkForce ''
        title Windows
        efi /efi/edk2-uefi-shell/shell.efi
        options -nointerrupt -noversion
        sort-key 0
      '');

      extraFiles."efi/edk2-uefi-shell/startup.nsh" = mkIf cfg.bootEntry.unstableFsAlias (
        pkgs.writeText "startup.nsh" ''
          @echo -off
          for %a in fs0 fs1 fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9
            if exist %a:\EFI\Microsoft\Boot\Bootmgfw.efi then
              %a:\EFI\Microsoft\Boot\Bootmgfw.efi
            endif
          endfor
          echo Windows bootloader not found.
        ''
      );
    };

    ns.userPackages = optional fsAliasConfigured (
      pkgs.makeDesktopItem {
        name = "boot-windows";
        desktopName = "Boot Windows";
        type = "Application";
        exec = "systemctl reboot --boot-loader-entry=windows_windows.conf";
        icon = "computer";
        categories = [ "System" ];
      }
    );

    programs.zsh.shellAliases = mkIf fsAliasConfigured {
      boot-windows = "systemctl reboot --boot-loader-entry=windows_windows.conf";
    };
  })
]
