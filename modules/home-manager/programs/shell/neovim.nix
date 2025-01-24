{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkIf
    optionalString
    hiPrio
    optional
    mkEnableOption
    ;
  inherit (config.${ns}.desktop.services) darkman;
in
{
  opts.neovide.enable = mkEnableOption "neovide";

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
      ltex-ls

      # Formatters
      nixfmt-rfc-style
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

    # Some treesitter parsers need this library
    extraWrapperArgs = [
      "--suffix"
      "LD_LIBRARY_PATH"
      ":"
      "${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    ];
  };

  home.packages = [
    (hiPrio (
      pkgs.runCommand "neovim-desktop-rename" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.neovim}/share/applications/nvim.desktop $out/share/applications/nvim.desktop \
          --replace-fail "Name=Neovim wrapper" "Name=Neovim"
      ''
    ))
  ] ++ optional cfg.neovide.enable pkgs.neovide;

  xdg.configFile."nvim".source = inputs.neovim-config.outPath;

  # For conditional nix-specific config in nvim config
  home.sessionVariables = {
    NIX_NEOVIM = 1;
    NIX_NEOVIM_DARKMAN = if darkman.enable then 1 else 0;
  };

  xdg.mimeApps = mkIf config.${ns}.desktop.enable {
    defaultApplications = {
      "text/plain" = [ "nvim.desktop" ];
    };
  };

  programs.zsh.initExtra =
    let
      inherit (config.${ns}.programs.desktop) alacritty;
    in
    optionalString alacritty.enable # bash
      ''
        # Disables alacritty opacity when launching nvim
        nvim() {
          if [ -z "$DISPLAY" ] || [ "$TERM" != "alacritty" ]; then
            command nvim "$@"
          else
            alacritty msg config window.opacity=1; command nvim "$@"; alacritty msg config --reset
          fi
        }
      '';

  # Change theme of all active Neovim instances
  darkman.switchScripts.neovim =
    theme: # bash
    ''
      ls "$XDG_RUNTIME_DIR"/nvim.*.0 | xargs -I {} \
        nvim --server {} --remote-expr "execute('Sunset${if theme == "dark" then "Night" else "Day"}')"
    '';

  nsConfig.persistence.directories = [
    ".cache/nvim"
    ".local/share/nvim"
    ".local/state/nvim"
  ];
}
