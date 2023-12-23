{
  # https://forum.endeavouros.com/t/tutorial-add-a-systemd-boot-loader-menu-entry-for-a-windows-installation-using-a-separate-esp-partition/37431
  # mirror: https://archive.is/wwZaP
  # NOTE: This requires setting up the /tools/shellx64.efi and /windows.nsh files in the ESP partition
  boot.loader.systemd-boot = {
    extraEntries = {
      "windows.conf" = ''
        title     Windows
        efi       /tools/shellx64.efi
        options   -nointerrupt -noconsolein -noconsoleout windows.nsh
      '';
    };
  };

  programs.zsh.shellAliases = {
    bootwindows = "systemctl reboot --boot-loader-entry=windows.conf";
  };
}
