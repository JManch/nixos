{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    mapAttrs'
    nameValuePair
    singleton
    mkEnableOption
    ;
  inherit (config.${ns}.core) home-manager;
  inherit (config.hm.xdg) dataHome;

  steamAppIDs = {
    "BeamNG.drive" = 284160;
    "Red Dead Redemption 2" = 1174180;
    "Deep Rock Galactic" = 548430;
    Noita = 881100;
    iRacing = 266410;
    BONELAB = 1592190;
  };
in
{
  # -- Common steam launch commands --
  # Standard  : mangohud gamemoderun %command%
  # FPS Limit : MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%
  # Gamescope : gamescope -W 2560 -H 1440 -f -r 165 --mangoapp -- gamemoderun %command%

  # WARN: When mangohud is launched with gamescope toggling the overlay is
  # broken. The mangohud overlay will show if I remove no_display from my
  # config but as soon as it's toggled it can't be brought back
  # https://github.com/ValveSoftware/gamescope/issues/1532

  # -- Game Specific Tips --
  # RDR2 Modded Launch Arguments:
  # WINEDLLOVERRIDES=EasyHook,EasyHook64,EasyLoad64,NativeInterop,version,dinput8,ScriptHookRDR2,ModManager.Core,ModManager.NativeInterop,NLog=n,b %command%

  # Assetto Corsa Setup:
  # - Run assetto corsa once then close
  # - Launch winecfg in protontricks and enable hidden files in wine file browser
  # - Inside the winecfg libraries tab add a new override for library 'dwrite'
  # - Run `protontricks 244210 corefonts` (can also be installed through UI but the pop-ups are annoying)
  # - Download content manager and place in steamapps/common/assettocorsa folder
  # - Rename content manager executable to 'Content Manager Safe.exe'
  # - Symlink loginusers.vdf to the prefix with `ln -s ~/.steam/root/config/loginusers.vdf ~/.local/share/Steam/steamapps/compatdata/244210/pfx/drive_c/Program\ Files\ \(x86\)/Steam/config/loginusers.vdf`
  # - Launch content manager with `protontricks-launch --appid 244210 ./Content\ Manager\ Safe.exe`
  # - Set assetto corsa root directory to z:/home/joshua/../steamapps/common/assettocorsa (using the z: drive is important)
  # - Inside Settings/Content Manager/Appearance settings disable window transparency and hardware acceleration for UI
  # - Inside Settings/Content Manager/Drive click the 'Switch game start to Steam' button
  #   it will show a warning about replacing the AssettoCorsa.exe, proceed
  # - Close the protontricks-launch instance of content manager and launch assetto corsa from Steam
  # - When installing custom shaders patch install one of the latest versions (old stable versions don't work)

  # WARN: Having third mirrored monitor enabled before launching content
  # manager causes a black screen . The issue doesn't occur if I enable monitor
  # 3 after content manager has already launched. I suspect it's a hyprland bug
  # but needs further investigation.

  opts.lanTransfer = mkEnableOption "opening port for Steam LAN game transfer";

  userPackages = [ pkgs.steam-run ];

  programs.steam = {
    enable = true;
    protontricks.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  networking.firewall = mkIf cfg.lanTransfer {
    allowedTCPPorts = [ 27040 ];
    allowedUDPPortRanges = singleton {
      from = 27031;
      to = 27036;
    };
  };

  # Steam doesn't close cleanly when SIGTERM is sent to the main process so we
  # have to send SIGTERM to a specific child process and wait for the
  # steamwebhelper which likes to hang around.
  ns.system.desktop.uwsm = {
    serviceApps = [ "steam" ];
    appUnitOverrides."steam@.service" =
      let
        steamKiller = pkgs.writeShellApplication {
          name = "steam-killer";
          runtimeInputs = with pkgs; [
            coreutils
            systemd
            gnugrep
            gawk
            gnused
          ];
          text = ''
            processes=$(systemd-cgls --no-page --full --user-unit "$1")

            get_pid() {
              echo "$processes" | grep "$1" | awk '{print $1}' | sed 's/^[^0-9]*//'
            }

            pid_main=$(get_pid "steam -srt-logger-opened")
            pid_helper=$(get_pid "./steamwebhelper -nocrashdialog -lang=en_US")

            if [ -z "$pid_main" ] || [ -z "$pid_helper" ]; then
              echo "Could not find required Steam PIDs, aborting"
              exit 1
            fi

            if [ "$(echo "$pid_main$pid_helper" | wc -l)" -gt 1 ]; then
              echo "Unexpectedly found multiple PIDs to kill, aborting"
              exit 1
            fi

            echo "Sending SIGTERM to main Steam process..."
            kill -s 15 "$pid_main"
            while [ -e "/proc/$pid_main" ]; do sleep .5; done
            echo "Main Steam process successfully killed"

            echo "Waiting for steamwebhelper to exit..."
            while [ -e "/proc/$pid_helper" ]; do sleep .5; done
            echo "Steamwebhelper process successfully killed"
          '';
        };
      in
      ''
        [Service]
        ExecStop=-${getExe steamKiller} %n
      '';
  };

  ns.persistenceHome.directories = [
    ".steam"
    ".local/share/Steam"
  ];

  hm = mkIf home-manager.enable {
    ${ns} = {
      programs.desktop.gaming = {
        gameClasses = [
          "steam_app_.*"
          "cs2"
          "factorio"
          "hl2_linux"
        ];

        tearingExcludedClasses =
          map (game: "steam_app_" + toString steamAppIDs.${game}) [
            "Red Dead Redemption 2" # half-vsync without tearing is preferrable
            "Noita" # tearing lags cursor
          ]
          ++ [ "factorio" ];
      };

      persistence.directories = [ ".factorio" ];
    };

    # Fix slow steam client downloads https://redd.it/16e1l4h
    home.file.".steam/steam/steam_dev.cfg".text = ''
      @nClientDownloadEnableHTTP2PlatformLinux 0
    '';

    # Create compatdata symlinks to make finding proton prefixes easier
    xdg.dataFile = mapAttrs' (
      gameName: appID:
      nameValuePair "Steam/steamapps/compatdata/${gameName}" {
        source = config.hm.lib.file.mkOutOfStoreSymlink "${dataHome}/Steam/steamapps/compatdata/${toString appID}";
      }
    ) steamAppIDs;

    desktop.hyprland.settings.windowrulev2 = [
      # Main steam window
      "workspace emptym, class:^(steam)$, title:^(Steam)$"

      # Steam sign-in window
      "noinitialfocus, class:^(steam)$, title:^(Sign in to Steam)$"
      "workspace special:loading silent, class:^(steam)$, title:^(Sign in to Steam)$"

      # Friends list
      "float, class:^(steam)$, title:^(Friends List)$"
      "size 360 700, class:^(steam)$, title:^(Friends List)$"
      "center, class:^(steam)$, title:^(Friends List)$"
    ];
  };
}
