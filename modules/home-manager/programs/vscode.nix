{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf fetchers;
  cfg = config.modules.programs.vscode;
in
mkIf cfg.enable {
  # NOTE: To fix credential saving (signing in with gihub) need to add
  # "password-store": "gnome" to ~/.vscode/argv.json
  # https://code.visualstudio.com/docs/editor/settings-sync#_troubleshooting-keychain-issues

  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;
    enableExtensionUpdateCheck = false;
    enableUpdateCheck = false;

    extensions = with pkgs.vscode-extensions; [
      ms-vsliveshare.vsliveshare
      bbenoist.nix
      gruntfuggly.todo-tree
    ];

    userSettings = mkIf (fetchers.isWayland config) {
      # Prevents crash on launch
      "window.titleBarStyle" = "custom";
    };
  };

  persistence.directories = [
    ".config/Code"
    ".vscode"
  ];
}
