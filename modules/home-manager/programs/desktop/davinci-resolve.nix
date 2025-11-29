{ inputs }:
{
  imports = [ inputs.nix-resources.homeManagerModules.davinci-resolve-studio ];

  ns.persistence.directories = [
    ".local/share/DaVinciResolve"
    # Set this as the primary media storage
    # Also move the backup dir here Preferences->User->Project Save and Load
    ".local/state/DaVinciResolve"
  ];

  ns.desktop.hyprland.windowRules."davinci-resolve" = {
    matchers = {
      class = "resolve";
      title = "negative:resolve|Message";
      float = true;
    };
    params.size = "monitor_w*0.4 monitor_h*0.4";
    params.center = true;
  };
}
