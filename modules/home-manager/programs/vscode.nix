{ lib
, config
, pkgs
, ...
}:
let
  cfg = config.modules.programs.vscode;
in
lib.mkIf cfg.enable {

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
    userSettings = lib.mkIf (lib.fetchers.isWayland config) {
      # Prevents crash on launch
      "window.titleBarStyle" = "custom";
    };
  };

  impermanence.directories = [
    ".config/Code"
    ".vscode"
  ];
}
