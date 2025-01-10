# Use go-mtpfs to mount android file systems (couldn't get other tools to work)
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
