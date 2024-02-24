{
  imports = [ ./core.nix ];

  modules = {
    desktop = {
      windowManager = "Hyprland";

      hyprland = {
        modKey = "ALT";
        blur = false;
        logging = true;
      };

      programs = {
        anyrun.enable = true;
      };

      services = {
        wallpaper.randomise = true;
        waybar.enable = true;
        dunst.enable = true;
      };
    };

    shell.enable = true;

    programs = {
      alacritty.enable = true;
      btop.enable = true;
      firefox.enable = false;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };
  };
}
