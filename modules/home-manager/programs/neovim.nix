{ lib
, pkgs
, config
, osConfig
, ...
} @ args:
let
  inherit (lib) mkIf utils optionalString;
  cfg = config.modules.programs.neovim;
in
mkIf (cfg.enable && config.modules.shell.enable) {
  home.packages = [ pkgs.neovide ];

  programs.neovim = {
    enable = true;
    package = (utils.flakePkgs args "neovim-nightly-overlay").default;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      # Runtime dependendies
      fzf
      ripgrep
      gnumake
      gcc

      # Language servers
      lua-language-server
      nil
      nixd

      # Formatters
      nixpkgs-fmt
      stylua

      # NOTE: These 'extra' lsp and formatters should be installed on a
      # per-project basis using nix shell

      # clang-tools
      # ltex-ls
      # omnisharp-roslyn
      # matlab-language-server
      # prettierd
      # black
    ];
  };

  # For conditional nix-specific config in nvim config
  home.sessionVariables.NIX_NEOVIM = 1;

  xdg.mimeApps = mkIf osConfig.usrEnv.desktop.enable {
    defaultApplications = {
      "text/plain" = [ "nvim.desktop" ];
    };
  };

  programs.zsh.initExtra =
    let
      inherit (config.modules.programs) alacritty;
      inherit (config.programs.alacritty.settings.window) opacity;
    in
    optionalString alacritty.enable /*bash*/ ''
      nvim() {
        alacritty msg config window.opacity=1 && \
          command nvim "$@" && alacritty msg config window.opacity=${toString opacity}
      }
    ''
  ;

  persistence.directories = [
    ".cache/nvim"
    ".config/nvim"
    ".local/share/nvim"
    ".local/state/nvim"
  ];
}
