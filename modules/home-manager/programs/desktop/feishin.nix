{ lib, pkgs }:
{
  home.packages = [
    # we don't want feishin loading mpv scripts
    (pkgs.symlinkJoin {
      name = "feishin-mpv-unwrapped";
      paths = [ pkgs.feishin ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/feishin \
          --prefix PATH : ${pkgs.mpv-unwrapped}/bin
      '';
    })
  ];

  ns.desktop = {
    services.playerctl.musicPlayers = lib.mkBefore [ "Feishin" ];

    uwsm.appUnitOverrides."feishin-.scope" = ''
      [Scope]
      KillMode=mixed
    '';

    hyprland.settings.windowrule = [
      "workspace special:social silent, class:^(feishin)$"
    ];
  };

  ns.persistence.directories = [ ".config/feishin" ];
}
