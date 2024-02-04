{ lib
, pkgs
, inputs
, config
, nixosConfig
, ...
}:
let
  inherit (lib) mkIf mkMerge lists;
  cfg = config.modules.desktop.services.wallpaper;
  allWallpapers = inputs.nix-resources.packages.${pkgs.system}.wallpapers.all-wallpapers;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;

  randomiseWallpaper = pkgs.writeShellScript "randomise-wallpaper" /*bash*/ ''
    DIR="${allWallpapers}/wallpapers"
    CACHE_FILE="${config.xdg.cacheHome}/wallpaper"
    if [[ -f "$CACHE_FILE" ]]; then
        PREVIOUS_WALLPAPER=$(<"$CACHE_FILE")
    else
        PREVIOUS_WALLPAPER=""
    fi
    # Randomly select a wallpaper excluding the previous
    NEW_WALLPAPER=$(
      ${pkgs.findutils}/bin/find "$DIR" -type f ! -wholename "$PREVIOUS_WALLPAPER" -print0 |
      ${pkgs.coreutils}/bin/shuf -z -n 1 |
      ${pkgs.coreutils}/bin/tr -d '\0'
    )
    echo "$NEW_WALLPAPER" > "$CACHE_FILE"
  '';

  wallpaperToSet = if cfg.randomise then "\"$(<${config.xdg.cacheHome}/wallpaper)\"" else cfg.default;
in
mkIf (osDesktopEnabled && cfg.setWallpaperCmd != null) (mkMerge [
  {
    systemd.user.services.set-wallpaper = {
      Unit = {
        Description = "Set the desktop wallpaper";
        After = lists.optional cfg.randomise "randomise-wallpaper.service" ++ [ "graphical-session.target" ];
        Requisite = [ "graphical-session.target" ];
        X-SwitchMethod = "keep-old";
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = [ "${pkgs.coreutils}/bin/sleep 1" ]
          # If this is a fresh install and the wallpaper cache does not exist,
          # randomise straight away. This is because daily / weekly timers
          # won't necessarily trigger on the very first boot
          ++ lib.lists.optional cfg.randomise
          "${pkgs.bash}/bin/sh -c '[[ -f \"${config.xdg.cacheHome}/wallpaper\" ]] || ${randomiseWallpaper.outPath}'";
        ExecStart = "${pkgs.bash}/bin/sh -c '${cfg.setWallpaperCmd} ${wallpaperToSet}'";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  }

  (mkIf cfg.randomise {
    impermanence.files = [ ".cache/wallpaper" ];

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
          ExecStart = "${randomiseWallpaper.outPath}";
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
          # Using this with sd-switch unfortunately causes X-SwitchMethod to be ignored
          # OnActiveSec = 10;
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };

    };
  })
])
