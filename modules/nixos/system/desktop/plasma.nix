{
  lib,
  pkgs,
  config,
  username,
  categoryCfg,
  adminUsername,
}:
let
  inherit (lib) ns mkIf mkDefault;
  inherit (config.${ns}.core) home-manager;
in
{
  enableOpt = false;
  conditions = [ (categoryCfg.desktopEnvironment == "plasma") ];

  services.desktopManager.plasma6.enable = true;

  services.displayManager.plasma-login-manager.enable = true;

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kwin-x11
    elisa # music player
  ];

  # KDE GUI prompts for root password sometimes. Ideally it would prompt for
  # sudo on our admin user but I don't see an easy way to do that so this
  # works.
  users.users."root" = mkIf (username != adminUsername) {
    hashedPasswordFile = config.age.secrets."${adminUsername}Passwd".path;
  };

  # Partial workaround for Plasma performance issues:
  # https://github.com/NixOS/nixpkgs/issues/363068
  # https://github.com/nixos/nixpkgs/issues/126590
  nixpkgs.overlays = [
    (final: prev: {
      kdePackages = prev.kdePackages.overrideScope (
        kdeFinal: kdePrev: {
          # https://old.reddit.com/r/NixOS/comments/1pdtc3v/kde_plasma_is_slow_compared_to_any_other_distro/
          # https://github.com/NixOS/nixpkgs/issues/126590#issuecomment-3194531220
          plasma-workspace =
            let
              # the package we want to override
              basePkg = kdePrev.plasma-workspace;
              # a helper package that merges all the XDG_DATA_DIRS into a single directory
              xdgdataPkg = final.stdenv.mkDerivation {
                name = "${basePkg.name}-xdgdata";
                buildInputs = [ basePkg ];
                dontUnpack = true;
                dontFixup = true;
                dontWrapQtApps = true;
                installPhase = ''
                  mkdir -p $out/share
                  ( IFS=:
                    for DIR in $XDG_DATA_DIRS; do
                      if [[ -d "$DIR" ]]; then
                        ${prev.lib.getExe prev.lndir} -silent "$DIR" $out
                      fi
                    done
                  )
                '';
              };
              # undo the XDG_DATA_DIRS injection that is usually done in the qt wrapper
              # script and instead inject the path of the above helper package
              derivedPkg = basePkg.overrideAttrs {
                preFixup = ''
                  for index in "''${!qtWrapperArgs[@]}"; do
                    if [[ ''${qtWrapperArgs[$((index+0))]} == "--prefix" ]] && [[ ''${qtWrapperArgs[$((index+1))]} == "XDG_DATA_DIRS" ]]; then
                      unset -v "qtWrapperArgs[$((index+0))]"
                      unset -v "qtWrapperArgs[$((index+1))]"
                      unset -v "qtWrapperArgs[$((index+2))]"
                      unset -v "qtWrapperArgs[$((index+3))]"
                    fi
                  done
                  qtWrapperArgs=("''${qtWrapperArgs[@]}")
                  qtWrapperArgs+=(--prefix XDG_DATA_DIRS : "${xdgdataPkg}/share")
                  qtWrapperArgs+=(--prefix XDG_DATA_DIRS : "$out/share")
                '';
              };
            in
            derivedPkg;
        }
      );
    })
  ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.terminal = mkDefault "org.kde.konsole";
  };
}
