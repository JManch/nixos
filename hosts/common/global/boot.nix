{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = ["zfs"];
    kernelParams = ["nohibernate"];
  };

  services.zfs = {
    trim.enable = true;
    autoScrub.enable = true;
  };

  programs.zsh.shellAliases = {
    bootbios = "systemctl reboot --firmware-setup";
  };
}
