{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf fetchers;
  inherit (config.modules) desktop;
  cfg = config.modules.programs.vscode;
in
mkIf cfg.enable
{
  # NOTE: To fix credential saving (signing in with gihub) need to add
  # "password-store": "gnome" to ~/.vscode/argv.json
  # https://code.visualstudio.com/docs/editor/settings-sync#_troubleshooting-keychain-issues

  programs.vscode = {
    enable = true;
    # WARN: This is the only way I'm able to get C++ debugging to work. Because
    # vscode runs in a FHS, it won't inherit PATH from nix develop or nix shell
    # environments. Solution is to run nix shell inside the vscode terminal.
    # Also, some tooling such as LSP servers may need to be added here. I don't
    # use VSCode as my main editor though so not a big deal.
    package = pkgs.vscode.fhsWithPackages (ps: with ps; [
      gdb
    ]);

    userSettings = mkIf (fetchers.isWayland config) {
      # Prevents crash on launch
      "window.titleBarStyle" = "custom";
      "window.menuBarVisibility" = "toggle";
      "editor.fontFamily" = desktop.style.font.family;
      "git.autofetch" = true;
      "workbench.colorTheme" = "Ayu Mirage Bordered";
      "cmake.showOptionsMovedNotification" = false;
      "cmake.configureOnOpen" = false;
    };
  };

  persistence.directories = [
    ".config/Code"
    ".vscode"
  ];
}
