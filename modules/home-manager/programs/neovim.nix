{ lib
, pkgs
, config
, osConfig
, ...
} @ args:
let
  inherit (lib) mkIf utils;
  cfg = config.modules.programs.neovim;
in
mkIf (cfg.enable && config.modules.shell.enable) {
  home.packages = with pkgs; [
    neovide
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
    package = (utils.flakePkgs args "neovim-nightly-overlay").default;
    vimAlias = true;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    NIX_NEOVIM = 1;
  };

  xdg.mimeApps = mkIf osConfig.usrEnv.desktop.enable {
    defaultApplications = {
      "text/plain" = [ "nvim.desktop" ];
    };
  };

  persistence.directories = [
    ".cache/nvim"
    ".config/nvim"
    ".local/share/nvim"
    ".local/state/nvim"
  ];
}
