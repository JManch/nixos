{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf;
  inherit (config.modules) desktop;
  inherit (desktop) isWayland;
  cfg = config.modules.programs.vscode;
in
mkIf cfg.enable
{
  # NOTE: To fix credential saving (signing in with gihub) need to add
  # "password-store": "gnome" to ~/.vscode/argv.json
  # https://code.visualstudio.com/docs/editor/settings-sync#_troubleshooting-keychain-issues

  programs.vscode = {
    enable = true;
    package = (pkgs.vscode.overrideAttrs (finalAttrs: prevAttrs: {
      # Override the desktopItem and remove the `mimeTypes` attribute because
      # we never want VSCode opening as a default app
      desktopItem =
        let
          inherit (finalAttrs.passthru) executableName longName;
        in
        pkgs.makeDesktopItem {
          name = executableName;
          desktopName = longName;
          comment = "Code Editing. Redefined.";
          genericName = "Text Editor";
          exec = "${executableName} %F";
          icon = "vs${executableName}";
          startupNotify = true;
          startupWMClass = "Code";
          categories = [ "Utility" "TextEditor" "Development" "IDE" ];
          keywords = [ "vscode" ];
          actions.new-empty-window = {
            name = "New Empty Window";
            exec = "${executableName} --new-window %F";
            icon = "vs${executableName}";
          };
        };
      # WARN: This is the only way I'm able to get C++ debugging to work. Because
      # vscode runs in a FHS, it won't inherit PATH from nix develop or nix shell
      # environments. Solution is to run nix shell inside the vscode terminal.
      # Also, some tooling such as LSP servers may need to be added here. I don't
      # use VSCode as my main editor though so not a big deal.
    })).fhsWithPackages (ps: with ps; [
      gdb
    ]);

    userSettings = {
      # Prevents wayland crash on launch
      "window.titleBarStyle" = mkIf isWayland "custom";
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
