{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    hiPrio
    mkOption
    mkEnableOption
    types
    optionalAttrs
    optionals
    ;
  home = config.home.homeDirectory;
in
{
  enableOpt = false;

  opts = {
    lowercaseUserDirs = mkEnableOption "lowercase user dirs" // {
      default = (osConfig.${ns}.system.desktop.desktopEnvironment or false) == null;
    };

    removeMimeTypePackages = mkOption {
      type = with types; listOf package;
      default = [ ];
      apply = optionals (osConfig.${ns}.system.desktop.desktopEnvironment == null);
      description = ''
        List of packages that will be excluded from default mime associations by
        removing the MimeTypes key from their desktop entry. Only applies on
        hosts without a desktop environment.

        List associations with:
        grep -oP '^[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+(?==)' /etc/profiles/per-user/$username/share/applications/mimeinfo.cache | sort -u | while read -r mime; do                                                                                        took 25m49s
          printf '%-40s %s\n' "$mime" "$(xdg-mime query default "$mime")"
        done
      '';
    };
  };

  home.packages = [
    # Many applications need this for xdg-open url opening however packages
    # rarely include is as a dependency for some reason
    pkgs.xdg-utils
  ]
  ++ map (
    p:
    hiPrio (
      pkgs.runCommand "${p.name}-desktop-no-mime-types" { } ''
        mkdir -p $out/share/applications
        if [ -d "${p}/share/applications" ]; then
          for desktop_file in "${p}/share/applications/"*.desktop; do
            [ -e "$desktop_file" ] || continue
            filename=$(basename "$desktop_file")
            sed '/^MimeType=/d' "$desktop_file" > "$out/share/applications/$filename"
          done
        fi
      ''
    )
  ) cfg.removeMimeTypePackages;

  # https://github.com/NixOS/nixpkgs/issues/160923
  # WARN: This only works if the necessary environment variables (most
  # importantly PATH and XDG_DATA_DIRS) have been imported using
  # dbus-update-activation-environment --systemd in the window-manager
  # start-up.
  xdg.portal.xdgOpenUsePortal = true;

  xdg.userDirs = {
    enable = true;
    # https://github.com/nix-community/home-manager/pull/7937/changes#issuecomment-3372232126
    setSessionVariables = false;
    createDirectories = true;
    extraConfig.SCREENSHOTS = "${home}/Pictures/Screenshots";
  }
  // optionalAttrs cfg.lowercaseUserDirs {
    desktop = "${home}/desktop";
    documents = "${home}/documents";
    download = "${home}/downloads";
    music = "${home}/music";
    pictures = "${home}/pictures";
    videos = "${home}/videos";
    templates = "${home}/templates";
    publicShare = "${home}/public";
    extraConfig.SCREENSHOTS = "${home}/pictures/screenshots";
  };

  xdg.mimeApps.enable = osConfig.${ns}.system.desktop.desktopEnvironment == null;

  ns.desktop.hyprland.windowRules."xdg-portal-file-picker" =
    lib.${ns}.mkHyprlandCenterFloatRule "xdg-desktop-portal-gtk" 60
      60;
}
