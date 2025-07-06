{
  lib,
  cfg,
  args,
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
    getExe'
    getExe
    mkEnableOption
    ;
  inherit (config.${ns}.desktop.services) darkman;
  nvimPackage = pkgs.${ns}.nvim;
in
{
  opts.neovide.enable = mkEnableOption "neovide";

  programs.zsh.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    vimdiff = "nvim -d";
  };

  home.packages = [
    (lib.${ns}.wrapAlacrittyOpaque args nvimPackage)
    (hiPrio (
      pkgs.runCommand "neovim-desktop-rename" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.neovim}/share/applications/nvim.desktop $out/share/applications/nvim.desktop \
          --replace-fail "Name=Neovim wrapper" "Name=Neovim"
      ''
    ))
  ] ++ optional cfg.neovide.enable pkgs.neovide;

  xdg.configFile."nvim".source = inputs.neovim-config.outPath;

  home.sessionVariables = {
    EDITOR = "nvim";
    NIX_NEOVIM = 1; # this is just for our legacy config
    NIX_NEOVIM_DARKMAN = if darkman.enable then 1 else 0;
  };

  xdg.mimeApps = mkIf config.${ns}.desktop.enable {
    defaultApplications = {
      "text/plain" = [ "nvim.desktop" ];
    };
  };

  # Change theme of all active Neovim instances
  ns.desktop.darkman.switchScripts.neovim =
    theme: # bash
    ''
      ${getExe' pkgs.coreutils "ls"} "$XDG_RUNTIME_DIR"/nvf.*.0 | ${getExe' pkgs.findutils "xargs"} -I {} \
        ${getExe nvimPackage} --server {} --remote-expr "execute('Sunset${
          if theme == "dark" then "Night" else "Day"
        }')"
    '';

  ns.persistence.directories = [
    ".cache/nvf"
    ".local/share/nvf"
    ".local/state/nvf"
  ];
}
