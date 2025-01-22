{ lib, ... }:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    ;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.programs = {
    alacritty.enable = mkEnableOption "Alacritty";
    btop.enable = mkEnableOption "btop";
    cava.enable = mkEnableOption "cava";
    torBrowser.enable = mkEnableOption "Tor Browser";
    git.enable = mkEnableOption "Git and Lazygit";
    neovim.enable = mkEnableOption "Neovim";
    neovim.neovide.enable = mkEnableOption "Neovide";
    spotify.enable = mkEnableOption "Spotify";
    fastfetch.enable = mkEnableOption "Fastfetch";
    discord.enable = mkEnableOption "Discord";
    obs.enable = mkEnableOption "OBS";
    vscode.enable = mkEnableOption "VSCode";
    stremio.enable = mkEnableOption "Stremio";
    mpv.enable = mkEnableOption "mpv";
    mpv.jellyfinShim.enable = mkEnableOption "mpv jellyfin shim";
    chatterino.enable = mkEnableOption "Chatterino";
    images.enable = mkEnableOption "image tools";
    anki.enable = mkEnableOption "Anki";
    zathura.enable = mkEnableOption "Zathura";
    qbittorrent.enable = mkEnableOption "qBitorrent";
    mangohud.enable = mkEnableOption "MangoHud";
    r2modman.enable = mkEnableOption "r2modman";
    lutris.enable = mkEnableOption "Lutris";
    filenDesktop.enable = mkEnableOption "Filen Desktop";
    multiviewerF1.enable = mkEnableOption "Multiviewer for F1";
    prism-launcher.enable = mkEnableOption "Prism Launcher";
    unity.enable = mkEnableOption "Unity Game Engine";
    foot.enable = mkEnableOption "Foot";
    chromium.enable = mkEnableOption "Chromium";
    zed.enable = mkEnableOption "Zed Editor";
    foliate.enable = mkEnableOption "Foliate Ebook Reader";
    rnote.enable = mkEnableOption "Rnote";
    jellyfin-media-player.enable = mkEnableOption "Jellyfin Media Player";
    davinci-resolve.enable = mkEnableOption "Davinci Resolve";
    ghostty.enable = mkEnableOption "Ghostty";

    firefox = {
      enable = mkEnableOption "Firefox";
      backup = mkEnableOption "Firefox backup";
      hideToolbar = mkEnableOption "automatic toolbar hiding";
      runInRam = mkEnableOption "running Firefox in RAM";

      uiScale = mkOption {
        type = types.float;
        default = -1.0;
        description = "UI scaling factor";
      };
    };

    taskwarrior = {
      enable = mkEnableOption "Taskwarrior";

      primaryClient = mkEnableOption ''
        Whether this is the primary Taskwarrior client for this user
      '';

      userUuid = mkOption {
        type = types.str;
        default = "565b3910-9d0b-4c2c-9bfc-b3195aac9d8f";
        description = ''
          Randomly generated UUID that identifies a user on the Taskchampion
          sync server
        '';
      };
    };
  };
}
