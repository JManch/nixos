{ lib, config, username, ... }:
let
  cfg = config.modules.programs.adb;
in
lib.mkIf cfg.enable
{
  programs.adb.enable = true;
  users.users.${username}.extraGroups = [ "adbusers" ];
}
