{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  cfg = config.modules.programs.neovim;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    neovide
    # Tools
    fd
    # Language servers
    lua-language-server
    nil
    nixd
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

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  xdg.mimeApps = lib.mkIf nixosConfig.usrEnv.desktop.enable {
    defaultApplications = {
      "text/plain" = [ "nvim.desktop" ];
    };
  };

  impermanence.directories = [
    ".cache/nvim"
    ".config/nvim"
    ".local/share/nvim"
    ".local/state/nvim"
  ];

  home.sessionVariables.NIX_NEOVIM = 1;
}
