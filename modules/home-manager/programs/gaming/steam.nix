{
  ns,
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib)
    mkIf
    getExe'
    mapAttrs'
    nameValuePair
    ;
  inherit (config.xdg) dataHome;
  osSteam = osConfig'.${ns}.programs.gaming.steam or null;
  cfg = config.${ns}.programs.gaming.steam;

  steamAppIDs = {
    "BeamNG.drive" = 284160;
    "Red Dead Redemption 2" = 1174180;
    "Deep Rock Galactic" = 548430;
    Noita = 881100;
    iRacing = 266410;
  };

in
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    (osSteam.enable or true)
    "The Steam home-manager module requires the system module to be enabled"
  ];

  # Fix slow steam client downloads https://redd.it/16e1l4h
  home.file.".steam/steam/steam_dev.cfg".text = ''
    @nClientDownloadEnableHTTP2PlatformLinux 0
  '';

  # Create compatdata symlinks to make finding proton prefixes easier
  xdg.dataFile = mapAttrs' (
    gameName: appID:
    nameValuePair "Steam/steamapps/compatdata/${gameName}" {
      source = config.lib.file.mkOutOfStoreSymlink "${dataHome}/Steam/steamapps/compatdata/${toString appID}";
    }
  ) steamAppIDs;

  # WARN: Having third mirrored monitor enabled before launching seems to break
  # games (black screen in content manager). The issue doesn't occur if I
  # enable monitor 3 after content manager has already launched. I suspect it's
  # a hyprland bug but needs further investigation.

  # RDR2 Modded Launch Arguments:
  # WINEDLLOVERRIDES=EasyHook,EasyHook64,EasyLoad64,NativeInterop,version,dinput8,ScriptHookRDR2,ModManager.Core,ModManager.NativeInterop,NLog=n,b %command%

  # VR Launch Arguments:
  # PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/monado_comp_ipc XRT_COMPOSITOR_SCALE_PERCENTAGE=140 XRT_COMPOSITOR_COMPUTE=1 SURVIVE_GLOBALSCENESOLVER=0 SURVIVE_TIMECODE_OFFSET_MS=-6.94 %command%

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

  ${ns}.programs.gaming = {
    gameClasses = [
      "steam_app.*"
      "SDL Application"
      "factorio"
      "hl2_linux"
    ];

    tearingExcludedClasses =
      map (game: "steam_app" + toString steamAppIDs.${game}) [
        "Red Dead Redemption 2" # half-vsync without tearing is preferrable
        "Noita" # tearing lags cursor
        "BeamNG.drive" # tearing causes flashing in UI
      ]
      ++ [
        "factorio"
      ];
  };

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

  xdg.desktopEntries.beam-mp =
    let
      terminal = config.${ns}.desktop.terminal.exePath;
      protontricks = (osConfig'.programs.steam.protontricks.package or pkgs.protontricks).override {
        extraCompatPaths = lib.makeSearchPathOutput "steamcompattool" "" (
          osConfig'.programs.steam.extraCompatPackages or [ ]
        );
      };
      protontricks-launch = getExe' protontricks "protontricks-launch";
      launcherDir = "${dataHome}/Steam/steamapps/compatdata/284160/pfx/dosdevices/c:/users/steamuser/AppData/Roaming/BeamMP-Launcher";
      appID = toString steamAppIDs."BeamNG.drive";
    in
    mkIf config.${ns}.desktop.enable {
      name = "BeamMP";
      exec = "${terminal} --title BeamMP -e ${protontricks-launch} --cwd-app --appid ${appID} ${launcherDir}/BeamMP-Launcher.exe";
      terminal = false;
      type = "Application";
      icon = "application-x-generic";
      categories = [ "Game" ];
    };

  persistence.directories = [ ".factorio" ];
}
