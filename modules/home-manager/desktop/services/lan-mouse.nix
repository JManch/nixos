{
  lib,
  cfg,
  pkgs,
  args,
  config,
  inputs,
  osConfig,
  hostname,
}:
let
  inherit (lib)
    ns
    getExe
    mapAttrs'
    filterAttrs
    mapAttrsToList
    mkOption
    elem
    types
    nameValuePair
    mkBefore
    optionalAttrs
    hasAttr
    ;
  inherit (lib.${ns})
    hostIps
    flakePkgs
    mkHyprlandCenterFloatRule
    wrapHyprlandMoveToActive
    sliceSuffix
    ;
  inherit (config.age.secrets) lanMouseCert;
  lan-mouse =
    assert (
      lib.assertMsg (
        pkgs.lan-mouse.version == "0.10.0"
      ) "lan-mouse has a new release so I can remove the flake"
    );
    (flakePkgs args "lan-mouse").default;
  otherFingerprints = filterAttrs (
    h: _: h != hostname
  ) inputs.nix-resources.secrets.lanMouseAuthorizedFingerprints;
in
{
  opts = {
    port = mkOption {
      type = types.port;
      default = 4242;
    };

    defaultHosts = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Others hosts to activate on start-up.";
    };

    defaultPositions = mkOption {
      type =
        with types;
        nullOr (
          attrsOf (enum [
            "left"
            "right"
            "top"
            "bottom"
          ])
        );
      example = {
        "ncase-m1" = "right";
      };
      description = "Default position of other hosts relative to this host.";
    };
  };

  home.packages = [
    (wrapHyprlandMoveToActive args lan-mouse "de.feschber.LanMouse"
      "--run 'systemctl start --user lan-mouse'"
    )
    (pkgs.writeShellScriptBin "start-lan-mouse" ''
      set -e
      if [[ $# -eq 0 ]]; then
        echo "Usage: start-lan-mouse <hostname>"
        exit 1
      fi

      hostname=$1
      if [[ "$hostname" == "${hostname}" ]]; then
        echo "Error: Cannot start-lan-mouse on local host"
        exit 1
      fi

      if ping -c 1 -W 1 "$hostname.lan" >/dev/null; then
        host_address="$hostname.lan"
      elif ping -c 1 -W 1 "$hostname-vpn.lan" >/dev/null; then
        host_address="$hostname-vpn.lan"
      else
        echo "Host '$hostname' is not up"
        exit 1
      fi

      ssh "${config.home.username}@$host_address" systemctl start --user lan-mouse.service
      echo "Started lan-mouse on host $hostname"
    '')
  ];

  systemd.user.services."lan-mouse" = {
    Unit = {
      Description = "Lan Mouse";
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "app${sliceSuffix osConfig}.slice";
      ExecStart = "${getExe lan-mouse} --cert-path ${lanMouseCert.path} daemon";
    };
  };

  xdg.configFile."lan-mouse/config.toml".source = (pkgs.formats.toml { }).generate "config.toml" {
    port = cfg.port;

    authorized_fingerprints = mapAttrs' (h: fingerprint: nameValuePair fingerprint h) otherFingerprints;

    clients = mapAttrsToList (
      h: _:
      {
        hostname = h;
        ips = hostIps h;
      }
      // optionalAttrs (cfg.defaultPositions != null && hasAttr h cfg.defaultPositions) {
        position = cfg.defaultPositions.${h};
      }
      // optionalAttrs (elem h cfg.defaultHosts) {
        activate_on_startup = true;
      }
    ) otherFingerprints;
  };

  ns.firewall.allowedUDPPorts = [ cfg.port ];

  ns.desktop.hyprland.binds =
    let
      inherit (config.${ns}.desktop.hyprland) modKey;
      wlrctl = getExe pkgs.wlrctl;
    in
    [
      # Hacky way to switch between hosts with keybinds
      # https://github.com/feschber/lan-mouse/issues/260
      "${modKey}SHIFTCONTROL, Left, exec, ${wlrctl} pointer move 10 0; ${wlrctl} pointer move -10000 0"
      "${modKey}SHIFTCONTROL, Right, exec, ${wlrctl} pointer move -10 0; ${wlrctl} pointer move 10000 0"
      "${modKey}SHIFTCONTROL, Up, exec, ${wlrctl} pointer move 0 10; ${wlrctl} pointer move 0 -10000"
      "${modKey}SHIFTCONTROL, Down, exec, ${wlrctl} pointer move 0 -10; ${wlrctl} pointer move 0 10000"
    ];

  ns.desktop.hyprland.windowRules."lan-mouse" =
    mkHyprlandCenterFloatRule "de\\.feschber\\.LanMouse" 25
      60;

  programs.waybar.settings.bar = {
    modules-right = mkBefore [ "custom/lan-mouse" ];
    "custom/lan-mouse" = {
      format = "<span color='#${config.colorScheme.palette.base04}'>󰍽 </span> {}";
      exec = "systemctl is-active --quiet --user lan-mouse && echo -n 'Lan Mouse' || echo -n ''";
      interval = 30;
      on-click = "${getExe pkgs.app2unit} -t service de.feschber.LanMouse.desktop";
      on-click-right = "systemctl stop --user lan-mouse && ${getExe pkgs.libnotify} --urgency=critical -t 5000 'Lan Mouse' 'Service stopped'";
      tooltip = false;
    };
  };
}
