{
  lib,
  config,
  username,
}:
let
  inherit (lib) ns;
in
{
  # Allows user services like home-manager syncthing to start on boot and
  # keep running rather than stopping and starting with each ssh session on
  # servers
  users.users.${username}.linger = config.${ns}.core.device.type == "server";

  programs.zsh.shellAliases = {
    sys = "systemctl";
    sysu = "systemctl --user";
  };
}
