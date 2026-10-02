{ lib, pkgs, ... }:
let
  inherit (lib) ns getExe;
in
{
  ${ns} = {
    core = {
      configManager = true;
      backupFiles = true;
    };

    desktop = {
      enable = true;
      terminal = "Alacritty";
      windowManager = "hyprland";
      locker = "hyprlock";
      launcher = "fuzzel";
      xdg.lowercaseUserDirs = true;

      hyprland = {
        tearing = true;
        directScanout = false;
        logging = false;
        hyprcursor.package = null;
        binds =
          let
            modifyBrightness = pkgs.writeShellScript "hypr-modify-brightness" ''
              read -r _ _ _ current max < <(${getExe pkgs.ddcutil} --skip-ddc-checks --bus 6 --terse getvcp 10) || exit 1
              new=$(( current $1 ))
              (( new > max )) && new=$max
              (( new < 0 )) && new=0
              if (( new != current )); then
                ${getExe pkgs.ddcutil} --noverify --skip-ddc-checks --bus 6 setvcp 10 "$new"
              fi
              brightness=$(( new * 100 / max ))
              ${getExe pkgs.libnotify} --transient --urgency=low -t 2000 \
                -h 'string:x-canonical-private-synchronous:brightness' "Display" "Brightness $brightness%"
            '';
          in
          [
            (lib.${ns}.mkHyprExec "mod" "F6" "${modifyBrightness} +10")
            (lib.${ns}.mkHyprExec "mod" "F5" "${modifyBrightness} -10")
          ];
      };

      services = {
        waybar.enable = true;
        dunst.enable = true;
        hypridle.enable = true;
        wayvnc.enable = true;
        awww.enable = true;
        hyprsunset.enable = true;

        lan-mouse = {
          enable = true;
          defaultHosts = [ "framework" ];
          defaultPositions."framework" = "bottom";
        };

        wallpaper = {
          randomise.enable = true;
          randomise.frequency = "*-*-* 05:00:00";
        };

        darkman = {
          enable = true;
          switchMethod = "hass";
          hassEntity = "joshua_dark_mode_brightness_threshold";
        };
      };
    };

    programs = {
      shell = {
        enable = true;
        atuin.enable = true;
        btop.enable = true;
        cava.enable = true;
        claude-code.enable = true;
        pi-coding-agent.enable = true;
        git.enable = true;
        fastfetch.enable = true;
        neovim.enable = true;

        taskwarrior = {
          enable = true;
          primaryClient = true;
        };
      };

      desktop = {
        alacritty.enable = true;
        ghostty.enable = true;
        tor-browser.enable = true;
        spotify.enable = true;
        feishin.enable = true;
        supersonic.enable = false;
        discord.enable = true;
        obs.enable = true;
        vscode.enable = true;
        mpv.enable = true;
        mpv.jellyfinShim.enable = true;
        images.enable = true;
        anki.enable = true;
        zathura.enable = true;
        qbittorrent.enable = true;
        filen-desktop.enable = false;
        multiviewer.enable = true;
        chromium.enable = true;
        foliate.enable = true;
        rnote.enable = true;
        jellyfin-media-player.enable = true;
        davinci-resolve.enable = false;
        signal.enable = true;
        halloy.enable = true;
        silverbullet.enable = true;

        chatterino = {
          enable = true;
          chatSide = "left";
        };

        firefox = {
          enable = true;
          backup = true;
          hideToolbar = true;
          runInRam = true;
          uiScale = 0.9;
        };

        gaming = {
          mangohud = {
            enable = true;
            fontSize = 18;
          };

          r2modman.enable = true;
          bottles.enable = false;
          prism-launcher.enable = true;
          mint.enable = true;
          osu.enable = true;
          beamng.enable = true;
          noita.enable = true;
        };
      };
    };

    services = {
      syncthing.enable = false;
      easyeffects.enable = true;
    };
  };

  home.stateVersion = "24.05";
}
