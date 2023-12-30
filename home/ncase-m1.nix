{ pkgs
, config
, ...
}: {
  imports = [
    ./core.nix
  ];

  home.packages = with pkgs; [
    discord
  ];

  modules = {
    shell.enable = true;

    desktop = {
      swaylock = {
        enable = true;
        lockScript = ''
          # Temporarily disable shader for screenshot
          COMMAND="${config.wayland.windowManager.hyprland.package}/bin/hyprctl keyword decoration:screen_shader ${config.xdg.configHome}/hypr/shaders/"
          ''${COMMAND}blank.frag > /dev/null 2>&1
          ${config.programs.swaylock.package}/bin/swaylock -f
          ${pkgs.coreutils}/bin/sleep 0.05
          ''${COMMAND}monitor1_gamma.frag > /dev/null 2>&1
        '';
      };
      swayidle = {
        enable = true;
        lockTime = 3 * 60;
        lockedScreenOffTime = 2 * 60;
      };
      anyrun.enable = true;
      waybar.enable = true;
    };

    programs = {
      alacritty.enable = true;
      btop.enable = true;
      cava.enable = true;
      firefox.enable = true;
      git.enable = true;
      neovim.enable = true;
      spotify.enable = true;
    };
  };
}
