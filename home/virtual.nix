{ pkgs, inputs, config, ... }:
{
  imports = [ ./core.nix ];

  modules = {
    desktop = {
      windowManager = "Hyprland";

      hyprland = {
        modKey = "ALT";
        blur = false;
      };

      terminal = {
        exePath = "${config.programs.alacritty.package}/bin/alacritty";
        class = "Alacritty";
      };

      style.font = {
        family = "BerkeleyMono Nerd Font";
        package = inputs.nix-resources.packages.${pkgs.system}.berkeley-mono-nerdfont;
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
      firefox.enable = true;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };
  };
}
