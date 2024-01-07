{ pkgs
, config
, lib
, inputs
, ...
}: {
  imports = [
    ./core.nix
  ];

  home.packages = with pkgs; [
    mpv
  ];

  modules = {
    shell.enable = true;

    desktop = {
      windowManager = "hyprland";

      style = {
        font = {
          family = "BerkeleyMono Nerd Font";
          package = inputs.nix-resources.packages.${pkgs.system}.berkeley-mono-nerdfont;
        };
        cursorSize = 24;
        cornerRadius = 10;
        borderWidth = 2;
        gapSize = 10;
      };

      swaylock = {
        enable = true;
        lockScript = lib.mkIf (config.modules.desktop.windowManager == "hyprland") ''
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
      dunst.enable = true;
      swww.enable = true;
    };

    programs = {
      alacritty.enable = true;
      btop.enable = true;
      cava.enable = true;
      firefox.enable = true;
      git.enable = true;
      neovim.enable = true;
      spotify.enable = true;
      fastfetch.enable = true;
      discord.enable = true;
      obs.enable = true;
      vscode.enable = true;
      stremio.enable = true;
    };

    services = {
      syncthing.enable = true;
    };
  };
}
