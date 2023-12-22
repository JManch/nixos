{
    # https://forum.endeavouros.com/t/tutorial-add-a-systemd-boot-loader-menu-entry-for-a-windows-installation-using-a-separate-esp-partition/37431
    loader.systemd-boot.extraEntries = {
      "windows.conf" = ''
        title     Windows
        efi       /tools/shellx64.efi
        options   -nointerrupt -noconsolein -noconsoleout windows.nsh
      ''
    };
    loader.systemd-boot.consoleMode = "max";
}
