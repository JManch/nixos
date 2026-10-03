{
  lib,
  pkgs,
  osConfig,
}:
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

    # Chromium apps randomly deploy scopes in app.slice
    uwsm.appUnitOverrides."feishin-.scope" = ''
      [Scope]
      Slice=app${lib.${lib.ns}.sliceSuffix osConfig}.slice
    '';

    hyprland.extraConf = # lua
      ''
        hl.window_rule({ match = { class = "feishin" }, workspace = "special:scratch2 silent" })
      '';
  };

  ns.persistence.directories = [ ".config/feishin" ];
}
