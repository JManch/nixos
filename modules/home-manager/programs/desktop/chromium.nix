{
  lib,
  pkgs,
  osConfig,
}:
{
  home.packages = [ pkgs.chromium ];

  ns.desktop = {
    xdg.removeMimeTypePackages = [ pkgs.chromium ];

    # Chromium apps randomly deploy scopes in app.slice
    uwsm.appUnitOverrides."org.chromium.Chromium-.scope" = ''
      [Scope]
      Slice=app${lib.${lib.ns}.sliceSuffix osConfig}.slice
    '';
  };

  ns.persistence.directories = [ ".config/chromium" ];
}
