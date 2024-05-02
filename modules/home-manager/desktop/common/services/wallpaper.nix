{ lib
, pkgs
, config
, osConfig
, ...
} @ args:
let
  inherit (lib) mkIf mkMerge boolToString optional getExe utils;
  inherit (config.modules.desktop.services) darkman;
  cfg = config.modules.desktop.services.wallpaper;
  wallpaperCache = "${config.xdg.cacheHome}/wallpaper";

  setWallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = optional darkman.enable config.services.darkman.package;
    text = /*bash*/ ''

      randomise=${boolToString cfg.randomise.enable};
      if [ "$randomise" = true ]; then
        darkman=${boolToString darkman.enable};
        if [ "$darkman" = true ]; then
          theme=$(darkman get)
          random_wallpaper_cache="${wallpaperCache}/$theme-wallpaper"
        else
          random_wallpaper_cache="${wallpaperCache}/wallpaper"
        fi

        # If the cache file doesn't exist we need to randomise
        if [ ! -f "$random_wallpaper_cache" ]; then
          ${getExe randomiseWallpaper};
        fi

        wallpaper=$(<"$random_wallpaper_cache")

        # Cached wallpaper paths might be invalid after garbage collection
        if [ ! -f "$wallpaper" ]; then
          ${getExe randomiseWallpaper};
          wallpaper=$(<"$random_wallpaper_cache")
        fi
      else
        wallpaper="${cfg.default}"
      fi
      ${cfg.setWallpaperCmd} "$wallpaper"

    '';
  };

  randomiseWallpaper = pkgs.writeShellApplication {
    name = "randomise-wallpaper";
    runtimeInputs = with pkgs; [ coreutils findutils ]
      ++ optional darkman.enable config.services.darkman.package;
    text =
      let
        wallpapers = type: "${(utils.flakePkgs args "nix-resources").wallpapers."${type}-wallpapers"}/wallpapers";
      in
        /*bash*/ ''

        function randomise_cache() {
          wallpapers="$1"
          cache_file="$2"
          previous_wallpaper=""
          [[ -f "$cache_file" ]] && previous_wallpaper=$(<"$cache_file")
          # Randomly select a wallpaper excluding the previous
          new_wallpaper=$(
            find "$wallpapers" -type f ! -wholename "$previous_wallpaper" -print0 |
            shuf -z -n 1 | tr -d '\0'
          )
          echo "$new_wallpaper" > "$cache_file"
        }

      darkman=${boolToString darkman.enable}
        if [ "$darkman" = true ]; then
          randomise_cache "${wallpapers "dark"}" "${wallpaperCache}/dark-wallpaper"
          randomise_cache "${wallpapers "light"}" "${wallpaperCache}/light-wallpaper"
        else
          randomise_cache "${wallpapers "all"}" "${wallpaperCache}/wallpaper"
        fi

      '';
  };
in
mkIf (osConfig.usrEnv.desktop.enable && cfg.setWallpaperCmd != null) (mkMerge [
  {
    systemd.user.services.set-wallpaper = {
      Unit = {
        Description = "Set the desktop wallpaper";
        X-SwitchMethod = "keep-old";
        PartOf = [ "graphical-session.target" ];
        Requisite = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
        ] ++ optional cfg.randomise.enable "randomise-wallpaper.service"
        ++ optional darkman.enable "darkman.service";
      };

      Service = {
        Type = "oneshot";
        ExecStart = getExe setWallpaper;
      };

      Install.WantedBy = optional (!(darkman.enable && cfg.randomise.enable)) "graphical-session.target";
    };
  }

  (mkIf cfg.randomise.enable {
    persistence.directories = [ ".cache/wallpaper" ];

    programs.zsh.shellAliases.randomise-wallpaper = "systemctl start --user randomise-wallpaper";

    darkman.switchScripts.wallpaper = theme: /*bash*/ ''
      systemctl start --user set-wallpaper
    '';

    systemd.user = {
      services.randomise-wallpaper = {
        Unit = {
          Description = "Randomise the desktop wallpaper";
          Before = [ "set-wallpaper.service" ];
          Wants = [ "set-wallpaper.service" ];
          X-SwitchMethod = "keep-old";
        };

        Service = {
          Type = "oneshot";
          ExecStart = [ (getExe randomiseWallpaper) ];
        };
      };

      timers.randomise-wallpaper = mkIf (!darkman.enable) {
        Unit = {
          Description = "Timer for randomising the desktop wallpaper";
          X-SwitchMethod = "keep-old";
        };

        Timer = {
          OnCalendar = cfg.randomise.frequency;
          Persistent = true;
        };

        Install.WantedBy = [ "timers.target" ];
      };
    };
  })
])
