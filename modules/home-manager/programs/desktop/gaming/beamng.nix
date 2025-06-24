{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkIf getExe;
  inherit (config.${ns}) desktop;
in
{
  requirements = [ "osConfig.programs.gaming.steam" ];

  # Native Linux version setup:
  # - Add non-steam game pointing to .local/share/Steam/steamapps/common/BeamNG.drive/BinLinux/BeamNG.drive.x64
  # - Set compatibilty tool to steam linux runtime 3.0
  categoryConfig = {
    gameClasses = [ "BeamNG\\.drive\\.x64" ];
    # Disable tearing in both the steam and linux version as it causes flashing
    # in the UI
    tearingExcludedClasses = [
      "steam_app_284160"
      "BeamNG\\.drive.x64"
    ];
  };

  home.packages = [ pkgs.${ns}.beammp-launcher ];

  xdg.desktopEntries = {
    beamng-scheme-handler = {
      name = "beamng:// scheme handler";
      type = "Application";
      terminal = false;
      exec = "${config.xdg.dataHome}/Steam/steamapps/common/BeamNG.drive/BinLinux/BeamNG_scheme_handler.sh %u";
      mimeType = [ "x-scheme-handler/beamng" ];
      noDisplay = true;
      settings.Version = "1.0";
    };

    beammp-launcher =
      let
        xdg-terminal = getExe pkgs.xdg-terminal-exec;
        beammp-launcher = getExe pkgs.${ns}.beammp-launcher;
      in
      mkIf desktop.enable {
        name = "BeamMP Launcher";
        exec = "${xdg-terminal} --title=BeamMP -e ${beammp-launcher} --no-launch --no-update";
        settings.Path = "${config.xdg.dataHome}/BeamMP";
        terminal = false;
        type = "Application";
        icon = (
          pkgs.fetchurl {
            name = "beammp-icon.png";
            url = "https://avatars.githubusercontent.com/u/76395149";
            hash = "sha256-hogRsoB4l+pRh59QN6bNdUFHIP+d94HNwhTCftmhrp8=";
          }
        );
        categories = [ "Game" ];
      };
  };

  # Just to create the .local/share/BeamMP dir
  xdg.dataFile."BeamMP/nix-placeholder".text = "";

  ns.persistence.directories = [
    ".local/share/BeamNG.drive"
    ".local/share/BeamMP"
  ];
}
