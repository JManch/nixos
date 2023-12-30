{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.modules.programs.neovim;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    # Tools
    fd
    # Language servers
    lua-language-server
    nil
    # Formatters
    stylua
    nixpkgs-fmt
  ];

  programs.ripgrep.enable = true;
  programs.fzf.enable = true;

  programs.neovim = {
    enable = true;
    # package = pkgs.neovim-nightly;
    vimAlias = true;
  };

  home.sessionVariables.NIX_NEOVIM = 1;
}
