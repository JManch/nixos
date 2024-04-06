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

  upstream.programs.neovim = {
    enable = true;
    package = (utils.flakePkgs args "neovim-nightly-overlay").default;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    defaultEditor = true;
    # Some treesitter parsers need this library. I had to copy and modify the
    # home-manager module for this because the way neovim is wrapped makes it a
    # nightmare to override.
    extraLibraries = [ pkgs.stdenv.cc.cc.lib ];
    extraPackages = with pkgs; [
      # Runtime dependendies
      fzf
      ripgrep
      gnumake
      gcc
      luajit

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

  xdg.configFile."nvim".source = pkgs.fetchFromGitHub {
    repo = "nvim";
    owner = "JManch";
    rev = "dfb5bad5ed6ea34133d595a3a0ccf105b711d136";
    hash = "sha256-LfTwZMT6sSI4ze+qdUM/XCB1I+oZRP81rxs9ubs/9ew=";
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

      # Disables alacritty opacity when launching nvim
      nvim() {
        if [[ -z "$DISPLAY" ]]; then
          command nvim "$@"
        else
          alacritty msg config window.opacity=1 && \
            command nvim "$@" && alacritty msg config window.opacity=${toString opacity}
        fi
      }

    '';

  persistence.directories = [
    ".cache/nvim"
    ".local/share/nvim"
    ".local/state/nvim"
  ];
}
