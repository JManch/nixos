{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./global.nix

    ./shell
    ./desktop/hyprland
    ./desktop/gtk.nix
    ./programs/alacritty.nix
    ./programs/firefox.nix
    ./programs/spotify.nix
    ./programs/neovim.nix
    ./programs/cava.nix
    ./programs/btop.nix
    ./programs/git.nix
  ];

  home.packages = with pkgs; [
    discord
  ];

  desktop = {
    enable = true;
    compositor = "hyprland";
    monitors = [
      {
        name = "DP-2";
        primary = true;
        refreshRate = 120;
        width = 2560;
        height = 1440;
        workspaces = ["1" "3" "5" "7" "9"];
      }
      {
        name = "HDMI-A-1";
        refreshRate = 59.951;
        width = 2560;
        height = 1440;
        workspaces = ["2" "4" "6" "8"];
      }
      {
        name = "DP-3";
        width = 2560;
        height = 1440;
        enabled = false;
      }
    ];
    wayland = {
      swaylock = {
        enable = true;
        lockScript = ''
          # Temporarily disable shader for screenshot
          COMMAND="${config.wayland.windowManager.hyprland.package} keyword decoration:screen_shader ${config.xdg.configHome}/hypr/shaders/"
          ''${COMMAND}blank.frag > /dev/null 2>&1
          ${config.swaylock.package}/bin/swaylock -f
          ${pkgs.coreutils}/bin/sleep 0.05
          ''${COMMAND}monitor1_gamma.frag > /dev/null 2>&1
        '';
      };
      swayidle = {
        enable = true;
        lockTime = 3 * 60;
        lockedScreenOffTime = 2 * 60;
      };
    };
  };
}
