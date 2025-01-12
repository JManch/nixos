{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    optional
    ;
  inherit (config.${ns}.hardware) secureBoot;
  inherit (cfg.bootEntry) fsAlias;
  cfg = config.${ns}.system.windows;
in
mkMerge [
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
      ++ optional (secureBoot.enable && cfg.bootEntry.enable) ''
        You have enabled secure boot and the Windows boot entry. It is not
        recommended to use both as manually signing the edk2 shell reduces
        the security of secure boot and the declarative systemd-boot config
        for the windows boot options will not work as lanzaboote overrides
        it.
      '';

    # How to get the fs alias:
    # 1. Run `sudo blkid | grep vfat` and take note of the PARTUUID of the Windows 'EFI system partition'
    # 2. Make sure cfg.fsAlias is null and reboot into edk2-shell
    # 3. Take note of the fs alias starting with HD... for matching PARTUUID
    # 4. Set bootEntry.fsAlias to the alias and disable bootEntry.bootstrap

    # Detailed instructions:
    # https://forum.endeavouros.com/t/tutorial-add-a-systemd-boot-loader-menu-entry-for-a-windows-installation-using-a-separate-esp-partition/37431
    # Mirror: https://archive.is/wwZaP

    boot.loader.systemd-boot = {
      edk2-uefi-shell.enable = fsAlias == null;

      extraEntries."windows.conf" = mkIf (fsAlias != null) ''
        title     Windows
        sort-key  0
        efi       /EFI/edk2-shell/shellx64.efi
        options   -nointerrupt -nomap -noversion windows.nsh
      '';

      extraFiles."windows.nsh" = mkIf (fsAlias != null) (
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
