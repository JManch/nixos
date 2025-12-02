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
    types
    nameValuePair
    mkBefore
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
  opts.port = mkOption {
    type = types.port;
    default = 4242;
  };

  home.packages = [
    (wrapHyprlandMoveToActive args lan-mouse "de.feschber.LanMouse"
      "--run 'systemctl start --user lan-mouse'"
    )
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

    clients = mapAttrsToList (h: _: {
      hostname = h;
      ips = hostIps h;
    }) otherFingerprints;
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
