{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
lib.mkIf config.${ns}.programs.chromium.enable {
  home.packages = [ pkgs.chromium ];

  persistence.directories = [
    ".config/chromium"
  ];
}
