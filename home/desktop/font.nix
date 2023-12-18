{ pkgs, ... }: {
  font = {
    enable = true;
    family = "FiraCode Nerd Font";
    package = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
  };
}
