{
  lib,
  pkgs,
  osConfig,
}:
{
  home.packages = [
    pkgs.discord
    # Waiting for https://github.com/Vencord/Vesktop/pull/1198
    # (vesktop.override { withMiddleClickScroll = true; })
  ];

  ns.desktop = {
    hyprland.extraConf = # lua
      ''
        hl.window_rule({ match = { class = "vesktop|discord" }, workspace = "special:scratch3 silent" })
      '';

    # Chromium apps randomly deploy scopes in app.slice
    uwsm.appUnitOverrides."discord-.scope" = ''
      [Scope]
      Slice=app${lib.${lib.ns}.sliceSuffix osConfig}.slice
    '';
  };

  ns.persistence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
