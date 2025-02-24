# Use go-mtpfs to mount android file systems (couldn't get other tools to work)
{ username }:
{
  programs.adb.enable = true;
  users.users.${username}.extraGroups = [ "adbusers" ];
}
