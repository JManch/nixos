{
  lib,
  config,
  username,
  ...
}:
lib.mkIf config.${lib.ns}.programs.adb.enable {
  programs.adb.enable = true;
  users.users.${username}.extraGroups = [ "adbusers" ];
}
