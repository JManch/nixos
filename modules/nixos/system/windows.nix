{ lib
, pkgs
, config
, ...
}:
let
  cfg = config.modules.system.windowsBootEntry;
in
lib.mkIf cfg.enable {

  # Enable mounting windows ntfs drive
  environment.systemPackages = [ pkgs.ntfs3g ];

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
      (lib.mkIf cfg.bootstrap {
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
}
