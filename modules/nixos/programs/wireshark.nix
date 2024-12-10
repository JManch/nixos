{
  lib,
  pkgs,
  config,
  username,
  ...
}:
let
  cfg = config.${lib.ns}.programs.wireshark;
in
lib.mkIf cfg.enable {
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  users.users.${username}.extraGroups = [ "wireshark" ];
}
