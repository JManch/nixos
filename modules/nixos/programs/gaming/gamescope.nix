{
  programs.gamescope = {
    enable = true;
    # Would like to enable this but it causes gamescope to stop working in lutris and steam
    # https://discourse.nixos.org/t/unable-to-activate-gamescope-capsysnice-option/37843
    capSysNice = false;
  };
}
