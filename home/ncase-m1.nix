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
    feh
  ];

  modules = {
    shell.enable = true;

    desktop = {
      windowManager = "hyprland";

      hyprland.tearing = true;

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
        lockScript =
          let
            hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
            shaderDir = "${config.xdg.configHome}/hypr/shaders/";
            cmd = "${hyprctl} keyword decoration:screen_shader ${shaderDir}";
          in
          lib.mkIf (config.modules.desktop.windowManager == "hyprland") /*bash*/
            (pkgs.writeShellScript "swaylock-lock" ''
              # Temporarily disable shader for screenshot
              ${cmd}blank.frag
              ${config.programs.swaylock.package}/bin/swaylock -f
              ${pkgs.coreutils}/bin/sleep 0.1
              ${cmd}monitor1_gamma.frag
            '').outPath;
      };

      swayidle = {
        enable = true;
        lockTime = 3 * 60;
        screenOffTime = 4 * 60;
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
      mpv.enable = true;
      chatterino.enable = true;
      images.enable = true;
    };

    services = {
      syncthing.enable = true;
      easyeffects = {
        enable = true;
        autoloadDevices = [
          {
            deviceName = "blue-snowball";
            deviceType = "input";
            config = /* json */ ''
              {
                "device": "alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_201306-00.mono-fallback",
                "device-description": "Blue Snowball Mono",
                "device-profile": "analog-input-mic",
                "preset-name": "improved-microphone"
              }
            '';
          }
        ];
      };
    };
  };
}
