{ pkgs
, inputs
, ...
}: {
  imports = [
    ./core.nix
  ];

  modules = {
    desktop = {
      wallpaper = {
        randomise = true;
        # randomiseFrequency = "*-*-* *:*:00"; # every minute for debug
      };
      windowManager = "hyprland";
      hyprland = {
        modKey = "ALT";
        blur = false;
      };
      style.font = {
        family = "BerkeleyMono Nerd Font";
        package = inputs.nix-resources.packages.${pkgs.system}.berkeley-mono-nerdfont;
      };
      anyrun.enable = true;
      waybar.enable = true;
      dunst.enable = true;
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
