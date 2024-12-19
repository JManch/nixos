{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.${lib.ns}.programs.davinci-resolve;
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
      "tag +davinci_resize, floating:1, class:^(resolve)$"
      "tag -davinci_resize, tag:davinci_resize*, title:^(resolve|Message)$"
      "size 40% 40%, tag:davinci_resize"
      "center, tag:davinci_resize"
    ];
  };
}
