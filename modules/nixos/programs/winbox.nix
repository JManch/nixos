{ lib, config, ... }:
lib.mkIf (config.modules.programs.winbox.enable)
{
  # NOTE: If Winbox stops working, deleting the ~/.local/share/winbox/wine
  # directory tends to fix it

  programs.winbox = {
    enable = true;
    openFirewall = true;
  };

  persistenceHome.directories = [ ".local/share/winbox" ];
}
