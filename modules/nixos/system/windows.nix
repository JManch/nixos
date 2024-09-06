{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf mkMerge optional;
  inherit (config.${ns}.hardware) secureBoot;
  cfg = config.${ns}.system.windows;
in
mkMerge [
  (mkIf cfg.enable {
    # Enable mounting windows ntfs drive
    environment.systemPackages = [ pkgs.ntfs3g ];
  })

  (mkIf cfg.bootEntry.enable {
    warnings =
      optional (cfg.bootEntry.fsAlias == "") ''
        The Windows fs alias is empty. The Windows boot entry will NOT work.
      ''
      ++ optional (secureBoot.enable && cfg.bootEntry.enable) ''
        You have enabled secure boot and the Windows boot entry. It is not
        recommended to use both as manually signing the edk2 shell reduces
        the security of secure boot and the declarative systemd-boot config
        for the windows boot options will not work as lanzaboote overrides
        it.
      '';

    # How to get the fs alias:
    # 1. Run `sudo blkid | grep vfat` and take note of the PARTUUID of the Windows 'EFI system partition'
    # 2. Enable bootEntry.bootstrap and reboot into edk2-shell
    # 3. Take note of the fs alias starting with HD... for matching PARTUUID
    # 4. Set bootEntry.fsAlias to the alias and disable bootEntry.bootstrap

    # Detailed instructions:
    # https://forum.endeavouros.com/t/tutorial-add-a-systemd-boot-loader-menu-entry-for-a-windows-installation-using-a-separate-esp-partition/37431
    # Mirror: https://archive.is/wwZaP

    boot.loader.systemd-boot = {
      extraFiles = {
        "EFI/edk2-shell/shellx64.efi" = pkgs.edk2-uefi-shell.efi;
      };

      extraEntries = {
        "windows.conf" = ''
          title     Windows
          efi       /EFI/edk2-shell/shellx64.efi
          options   -nointerrupt -noconsolein -noconsoleout windows.nsh
        '';

        "edk2-shell.conf" = mkIf cfg.bootEntry.bootstrap ''
          title edk2-shell
          efi /efi/edk2-shell/shellx64.efi
        '';
      };

      extraFiles."windows.nsh" = mkIf (cfg.bootEntry.fsAlias != "") (
        pkgs.writeText "windows.nsh" ''
          ${cfg.bootEntry.fsAlias}:EFI\Microsoft\Boot\Bootmgfw.efi
        ''
      );
    };

    programs.zsh.shellAliases = {
      boot-windows = "systemctl reboot --boot-loader-entry=windows.conf";
    };
  })
]
