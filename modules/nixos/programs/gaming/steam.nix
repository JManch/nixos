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
    singleton
    mkEnableOption
    ;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.core) device;
in
{
  # WARN: If steam fails to launch with "couldn't setup Steam data" on a fresh
  # install, delete the contents of .steam and .local/share/Steam

  # -- Common steam launch commands --
  # Standard  : mangohud gamemoderun %command%
  # FPS Limit : MANGOHUD_CONFIG=read_cfg,fps_limit=200 mangohud gamemoderun %command%
  # Gamescope : gamescope -W 2560 -H 1440 -f -r 165 --mangoapp -- gamemoderun %command%

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

  # Liftoff and Liftoff: Micro Drones
  # It's important to disable steam input otherwise our TX15 gets detected as
  # an xbox 360 controller and gets deadzones

  opts.lanTransfer = mkEnableOption "opening port for Steam LAN game transfer";

  ns.userPackages = [ pkgs.steam-run ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # Prefer wayland as clients automatically have their content type set to
      # "game" for our game-specific workspace and window rules
      extraEnv.PROTON_ENABLE_WAYLAND = 1;
    };
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
  ns.system.desktop.uwsm.appUnitOverrides."steam@.service" =
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

  ns.persistenceHome.directories = [
    ".steam"
    ".local/share/Steam"
  ];

  ns.hm = mkIf home-manager.enable {
    ${ns} = {
      programs.desktop.gaming = {
        gameClasses = [
          "steam_app_.*" # x11 proton games do not automatically get assigned the "game" content type
        ];

        tearingExcludedClasses = [
          "teardown\\.exe"
          "rdr2\\.exe" # half v-sync without tearing is preferable
          "factorio"
        ];
      };

      desktop.hyprland.windowRules = {
        "steam-main-window" = {
          matchers.class = "steam";
          matchers.title = "Steam";
          params.workspace = "emptym";
        };

        "steam-sign-in-window" = {
          matchers.class = "steam";
          matchers.title = "Sign in to Steam";
          params.no_initial_focus = true;
          params.workspace = "special:special silent";
        };

        "steam-friends-list" = {
          matchers.class = "steam";
          matchers.title = "Friends List";
          params = {
            float = true;
            size = "monitor_w*0.15 monitor_h*0.4";
            center = true;
          };
        };
      };

      persistence.directories = [
        ".factorio"
        ".config/unity3d/LemaitreBros/STRAFTAT"
      ];
    };

    # Fix slow steam client downloads https://redd.it/16e1l4h
    # Speed up shader processing by using more than a single thread
    home.file.".steam/steam/steam_dev.cfg".text = ''
      @nClientDownloadEnableHTTP2PlatformLinux 0
      unShaderBackgroundProcessingThreads ${toString device.cpu.threads}
    '';
  };
}
