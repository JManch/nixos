# The only reliable way to export all home-manager variables into the
# systemd user environment with UWSM is to start it from the TTY (not using a
# display manager like greetd). For some reason display managers do not
# source our user's .zshenv before UWSM exports the login shell variables into
# the systemd user environment. Can be partly worked around with
# systemd.user.sessionVariables = config.home.sessionVariables but this
# doesn't account for home.sessionSearchVariables or home.sessionVariablesExtra
# https://github.com/nix-community/home-manager/blob/da624eaad0fefd4dac002e1f09d300d150c20483/modules/home-environment.nix#L611.

# Eventually hopefully all home.session* options will use `environment.d` so
# they'll get directly exported into the systemd user environment instead of
# being transfered from the login shell env. Then display managers will be
# viable again.
# https://github.com/nix-community/home-manager/issues/2659
{ lib }:
let
  inherit (lib) types mkOption;
in
{
  enableOpt = false;
  conditions = [ "osConfig.system.desktop.uwsm" ];

  opts.appUnitOverrides = mkOption {
    type = types.attrs;
    default = { };
    description = ''
      Attribute set of unit overrides. Attribute name should be the unit
      name without the app-''${desktop} prefix. Attribute value should be
      the multiline unit string.
    '';
  };

  # The tray Requires "graphical-session-pre.target" which is bad practice
  xdg.configFile."systemd/user/tray.target".enable = false;

  # Not perfect as it won't work for apps that wrap themselves with xdg-utils.
  # Don't want to overlay xdg-utils to avoid mass rebuilds.
  # FIX: Breaks open-with behaviour in some apps. For example in picard when
  # opening cover art in an external program.
  # home.packages = [
  #   (lib.hiPrio (
  #     pkgs.runCommand "app2unit-xdg-open" { } ''
  #       mkdir -p $out/bin
  #       ln -s ${pkgs.app2unit}/bin/app2unit-open $out/bin/xdg-open
  #     ''
  #   ))
  # ];

  programs.zsh.shellAliases."xdg-open" = "app2unit-open -t service";
}
