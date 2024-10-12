{
  ns,
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.${ns}.programs.davinci-resolve;
in
{
  imports = [ inputs.nix-resources.homeManagerModules.davinci-resolve-studio ];

  config = lib.mkIf cfg.enable {
    persistence.directories = [
      ".local/share/DaVinciResolve"
      # Set this as the primary media storage
      # Also move the backup dir here Preferences->User->Project Save and Load
      ".local/state/DaVinciResolve"
    ];

    desktop.hyprland.settings.windowrulev2 = [
      "size 40% 40%, floating:1, class:^(resolve)$, title:^(?!resolve$)(?!Message$).*"
      "center, floating:1, class:^(resolve)$, title:^(?!resolve$)(?!Message$).*"
    ];
  };
}
