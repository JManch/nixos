{ lib
, pkgs
, config
, username
, ...
}:
let
  inherit (lib) mkIf getExe getExe';
  inherit (config.device) gpu;
  cfg = config.modules.services.corectrl;
  corectrl = getExe' config.programs.corectrl.package "corectrl";
in
mkIf (cfg.enable && (gpu.type == "amd"))
{
  # TODO: Someday I'd like to replace all of the corectrl functionality with
  # same basic scripts or a small program. There's way too much complexity in
  # this application for the basic GPU settings I want to change whilst
  # gaming...

  users.users.${username}.extraGroups = [ "corectrl" ];

  programs.corectrl = {
    enable = true;

    # Latest version has 7900xt fan curve support
    package = pkgs.corectrl.overrideAttrs (prev: {
      version = "2024-02-27";

      src = pkgs.fetchFromGitLab {
        owner = "corectrl";
        repo = "corectrl";
        rev = "f8bf0e920df2358ee9e98d61bd74b2e357b04a94";
        sha256 = "sha256-v2Ugy4ZaZGBgjU9lJlbQ2qv/3qa6DQYKw5XvRx55GqY=";
      };

      # Patch includes a --hide-window launch option to hide the window no
      # matter what. Useful for running in a background systemd service. Also
      # includes a --set-manual-profile option that accepts "<profile_name>
      # <enable or disable>" for explicitly controlling profile states rather
      # than just toggling.
      patches = (prev.patches or [ ]) ++ [ ../../../patches/corectrlImprovements.patch ];

      buildInputs = with pkgs; prev.buildInputs ++ [ spdlog pugixml ];
    });

    # WARN: Disable this if you experience flickering or general instability
    # https://wiki.archlinux.org/title/AMDGPU#Boot_parameter
    gpuOverclock.enable = true;
    gpuOverclock.ppfeaturemask = "0xffffffff";
  };

  # WARN: If the graphical-session is shutdown in an unclean way the service
  # will fail to stop cleanly and the corectrl_helper dbus service is left
  # hanging. This causes subsequent corectl start-ups to fail until
  # corectrl_helper is manually killed.
  systemd.user.services = {
    corectrl = {
      unitConfig = {
        Description = "Corectrl system hardware tuner";
        # PartOf = [ "graphical-session.target" ]; pointless because of above issue
        After = [ "graphical-session-pre.target" ];
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${corectrl} --hide-window";
        # Closing the window fully quits corectrl so we have to force restart
        Restart = "on-success";
        RestartSec = 3;
      };

      wantedBy = [ "graphical-session.target" ];
    };

    corectrl-gamemode-profile = {
      unitConfig = {
        Description = "Enable Corectrl gamemode profile";
        Requisite = [ "corectrl.service" ];
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${corectrl} --set-manual-profile \"Gamemode enable\"";
        ExecStop = "${corectrl} --set-manual-profile \"Gamemode disable\"";
        RemainAfterExit = true;
      };
    };
  };

  modules.programs.gaming.gamemode =
    let
      systemctl = getExe' pkgs.systemd "systemctl";
    in
    {
      startScript = "${systemctl} start --user corectrl-gamemode-profile";
      stopScript = "${systemctl} stop --user corectrl-gamemode-profile";
    };

  persistenceHome.directories = [ ".config/corectrl" ];
}
