{ lib
, pkgs
, config
, osConfig
, ...
} @ args:
let
  inherit (lib) mkIf mkMerge lists getExe utils;
  cfg = config.modules.desktop.services.wallpaper;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;
  allWallpapers = (utils.flakePkgs args "nix-resources").wallpapers.all-wallpapers;

  randomiseWallpaper = pkgs.writeShellApplication {
    name = "randomise-wallpaper";
    runtimeInputs = with pkgs; [ coreutils findutils ];
    text = /*bash*/ ''

      DIR="${allWallpapers}/wallpapers"
      CACHE_FILE="${config.xdg.cacheHome}/wallpaper"
      [[ -f "$CACHE_FILE" ]] && PREVIOUS_WALLPAPER=$(<"$CACHE_FILE")
      # Randomly select a wallpaper excluding the previous
      NEW_WALLPAPER=$(
        find "$DIR" -type f ! -wholename "$PREVIOUS_WALLPAPER" -print0 |
        shuf -z -n 1 | tr -d '\0'
      )
      echo "$NEW_WALLPAPER" > "$CACHE_FILE"

    '';
  };
in
mkIf (osDesktopEnabled && cfg.setWallpaperCmd != null) (mkMerge [
  {
    systemd.user.services.set-wallpaper = {
      Unit = {
        Description = "Set the desktop wallpaper";
        X-SwitchMethod = "keep-old";
        Requisite = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
        ] ++ lists.optional cfg.randomise "randomise-wallpaper.service";
      };

      Service =
        let
          wallpaperToSet = if cfg.randomise then "\"$(<${config.xdg.cacheHome}/wallpaper)\"" else cfg.default;
        in
        {
          Type = "oneshot";
          ExecStartPre = [ "${pkgs.coreutils}/bin/sleep 1" ]
            # If this is a fresh install and the wallpaper cache does not exist,
            # randomise straight away. This is because daily / weekly timers
            # won't necessarily trigger on the very first boot

            # TODO: Minor issue but if full garbage collection is run and a
            # randomise is not triggered before the next boot the wallpaper path
            # inside the cache file will be invalidated and the wallpaper will
            # not be applied. Can maybe add a check that runs randomiseWallpaper
            # if the wallpaper file pointed to in the cache does not exist.
            ++ lib.lists.optional cfg.randomise
            "${pkgs.bash}/bin/sh -c '[[ -f \"${config.xdg.cacheHome}/wallpaper\" ]] || ${getExe randomiseWallpaper}'";
          ExecStart = "${pkgs.bash}/bin/sh -c '${cfg.setWallpaperCmd} ${wallpaperToSet}'";
        };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  }

  (mkIf cfg.randomise {
    persistence.files = [ ".cache/wallpaper" ];

    programs.zsh.shellAliases.randomise-wallpaper = "systemctl start --user randomise-wallpaper";

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
          ExecStart = [ "${getExe randomiseWallpaper}" ];
        };
      };

      timers.randomise-wallpaper = {
        Unit = {
          Description = "Timer for randomising the desktop wallpaper";
          X-SwitchMethod = "keep-old";
        };

        Timer = {
          Unit = "randomise-wallpaper.service";
          OnCalendar = cfg.randomiseFrequency;
          Persistent = true;
        };

        Install.WantedBy = [ "timers.target" ];
      };
    };
  })
])
