{ inputs
, pkgs
, ...
}: {
  imports = [
    ./core.nix
  ];

  modules = {
    desktop = {
      windowManager = "hyprland";
      hyprland.modKey = "ALT";
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
      cava.enable = true;
      firefox.enable = true;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };
  };
}
