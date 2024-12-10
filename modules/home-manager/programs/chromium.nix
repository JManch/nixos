{
  lib,
  pkgs,
  config,
  ...
}:
lib.mkIf config.${lib.ns}.programs.chromium.enable {
  home.packages = [ pkgs.chromium ];

  persistence.directories = [
    ".config/chromium"
  ];
}
