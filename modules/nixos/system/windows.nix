{ lib
, pkgs
, config
, ...
}:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.modules.system.windows;
  secureBoot = config.modules.hardware.systemdboot;
in
mkIf cfg.enable (mkMerge [
  {
    # Enable mounting windows ntfs drive
    environment.systemPackages = [ pkgs.ntfs3g ];
  }

  (mkIf cfg.bootEntry {
    warnings =
      if (secureBoot.enable && cfg.bootEntry) then [
        ''You have enabled secure boot and the windows boot entry. It is not
      recommended to use both as manually signing the edk2 shell reduces the
      security of secure boot and the declarative systemd-boot config for the
      windows boot options will not work as lanzaboote overrides it.''
      ] else [ ];

    # https://forum.endeavouros.com/t/tutorial-add-a-systemd-boot-loader-menu-entry-for-a-windows-installation-using-a-separate-esp-partition/37431
    # mirror: https://archive.is/wwZaP
    # NOTE: This requires setting up /windows.nsh in the ESP partition
    boot.loader.systemd-boot = {
      extraFiles = {
        "EFI/edk2-shell/shellx64.efi" = pkgs.edk2-uefi-shell.efi;
      };
      extraEntries = lib.mkMerge [
        {
          "windows.conf" = ''
            title     Windows
            efi       /EFI/edk2-shell/shellx64.efi
            options   -nointerrupt -noconsolein -noconsoleout windows.nsh
          '';
        }
        (mkIf cfg.bootstrap {
          "edk2-shell.conf" = ''
            title edk2-shell
            efi /efi/edk2-shell/shellx64.efi
          '';
        })
      ];
    };

    programs.zsh.shellAliases = {
      boot-windows = "systemctl reboot --boot-loader-entry=windows.conf";
    };
  })
])
