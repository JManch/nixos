{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf optionalString;
  cfg = config.modules.programs.neovim;
in
mkIf cfg.enable
{
  home.packages = [ pkgs.neovide ];

  programs.neovim = {
    enable = true;
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

    # Some treesitter parsers need this library. I had to copy and modify the
    # home-manager module for this because the way neovim is wrapped makes it a
    # nightmare to override.
    extraWrapperArgs = [
      "--suffix"
      "LD_LIBRARY_PATH"
      ":"
      "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    ];
  };

  xdg.configFile."nvim".source = pkgs.fetchFromGitHub {
    repo = "nvim";
    owner = "JManch";
    rev = "e239aaeec106dc883b751fd99554bfeea57079ad";
    hash = "sha256-NggXREdnZ0a9QMOGOTJkgi9QUyL0xxlFzuvLD8IyOuQ=";
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
    in
    optionalString alacritty.enable /*bash*/ ''

      # Disables alacritty opacity when launching nvim
      nvim() {
        if [[ -z "$DISPLAY" ]]; then
          command nvim "$@"
        else
          alacritty msg config window.opacity=1 \
            && command nvim "$@" && alacritty msg config \
            window.opacity="$(grep "^opacity" ${config.xdg.configHome}/alacritty/alacritty.toml | sed 's/opacity = //')"
        fi
      }

    '';

  persistence.directories = [
    ".cache/nvim"
    ".local/share/nvim"
    ".local/state/nvim"
  ];
}
