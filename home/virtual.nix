{ inputs
, pkgs
, ...
}: {
  imports = [
    ./core.nix
  ];

  modules = {
    desktop = {
      dunst.enable = true;
      style.font = {
        family = "BerkeleyMono Nerd Font";
        package = inputs.nix-resources.packages.${pkgs.system}.berkeley-mono-nerdfont;
      };
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
