{ lib, pkgs }:
let
  inherit (lib) ns mkBefore;
in
{
  home.packages = [
    # we don't want feishin loading mpv scripts
    (pkgs.symlinkJoin {
      name = "feishin-mpv-unwrapped";
      paths = [ (lib.${ns}.addPatches pkgs.feishin [ "feishin-notifications.patch" ]) ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/feishin \
          --prefix PATH : ${pkgs.mpv-unwrapped}/bin:${pkgs.libnotify}/bin
      '';
    })
  ];

  ns.programs.desktop.music.enable = true;

  ns.desktop = {
    services.playerctl.musicPlayers = mkBefore [ "Feishin" ];

    uwsm.appUnitOverrides."feishin@.service" = ''
      [Service]
      KillMode=mixed
    '';

    hyprland.settings.windowrule = [
      "match:class feishin, workspace special:music silent"
    ];
  };

  ns.persistence.directories = [ ".config/feishin" ];
}
