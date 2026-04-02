{
  lib,
  cfg,
  pkgs,
  self,
  inputs,
  config,
  username,
  hostname,
  adminUsername,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    genAttrs
    mapAttrs
    hasAttr
    optionalAttrs
    mkOption
    types
    optional
    optionalString
    elem
    attrNames
    optionals
    attrValues
    singleton
    mkEnableOption
    concatMapStrings
    concatStringsSep
    ;
  inherit (config.${ns}.system) virtualisation;
  inherit (inputs.nix-resources.secrets)
    keys
    uniSSHHostname
    uniUsername
    uniSSHJumpHostname
    ;
  inherit (config.${ns}.system) desktop;
  inherit (config.${ns}.core) home-manager;

  # Session variables shared over SSH between personal hosts
  sharedVariables = [
    "ZELLIJ" # to avoid nested zellij sessions
    "DARKMAN_THEME" # so ssh sessions can match local light/dark theme
  ];
in
{
  enableOpt = false;

  opts = {
    server = {
      enable = mkEnableOption "SSH server";

      extraInterfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of interfaces (in addition to the primary interfaces) that the
          SSH server should be exposed on.
        '';
      };
    };
    agent.enable = mkEnableOption "SSH authentication agent" // {
      default = username == adminUsername;
    };
  };

  services.gnome.gcr-ssh-agent.enable = cfg.agent.enable && desktop.enable;

  services.openssh = mkIf cfg.server.enable {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AcceptEnv = sharedVariables;
      AllowUsers = [
        "root"
        adminUsername
      ];
    };

    hostKeys = singleton {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    };
  };

  networking.firewall.interfaces =
    # Enable using this host as a build host in VMs
    optionalAttrs virtualisation.libvirt.enable {
      virbr0.allowedTCPPorts = [ 22 ];
    }
    // genAttrs cfg.server.extraInterfaces (_: {
      allowedTCPPorts = [ 22 ];
    });

  users.users.root.openssh.authorizedKeys.keys = [ keys.auth.personal ];
  users.users.${adminUsername}.openssh.authorizedKeys.keys = attrValues keys.auth;

  programs.ssh = {
    startAgent = cfg.agent.enable && !desktop.enable;
    agentTimeout = null;
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];
    extraConfig =
      optionalString cfg.agent.enable ''
        AddKeysToAgent yes
      ''
      + optionalString (username == "joshua") (
        ''
          Host uni
            HostName ${uniSSHHostname}
            User ${uniUsername}
            # The server is misconfigured and doesn't advertise ed25519 cert support
            PubkeyAcceptedAlgorithms +ssh-ed25519-cert-v01@openssh.com

          Host uni-jump
            HostName ${uniSSHJumpHostname}
            User ${uniUsername}
            # Has the same issue
            PubkeyAcceptedAlgorithms +ssh-ed25519-cert-v01@openssh.com

          Match originalhost uni exec "! ${getExe pkgs.netcat} -z -w 1 ${uniSSHHostname} 22"
            ProxyJump uni-jump
        ''
        + concatMapStrings (
          let
            # Enable agent forwarding on specific personal hosts
            forwardAgentHosts = [
              "ncase-m1"
              "framework"
            ];
          in
          host: ''
            Host ${host}*
              User joshua
              ForwardAgent ${if elem host forwardAgentHosts then "Yes" else "No"}
              SendEnv ${concatStringsSep " " sharedVariables}
          ''
        ) (attrNames self.nixosConfigurations)
      );

    knownHosts =
      (mapAttrs (host: _: {
        publicKey = keys.ssh-host.${host};
        extraHostNames = (
          [
            "${host}.lan"
            "${host}-vpn.lan"
          ]
          ++ optionals (hasAttr host self.nixosConfigurations) (lib.${ns}.hostIps host)
          ++ optional (host == hostname) "localhost"
        );
      }) (self.nixosConfigurations // self.nixOnDroidConfigurations))
      // {
        "router.lan".publicKey = keys.misc.router;
      }
      // mapAttrs (_: v: { publicKey = v; }) keys.external-ssh-host;
  };

  # We want sshfs mounts to disconnect on connection loss otherwise they will
  # block IO operations and hang applications until the VPN is reconnected.
  # For specific uses can also pass the '-o reconnect' flag which allows mounts
  # to reconnect when the network is accessible again.
  nixpkgs.overlays = singleton (
    final: prev: {
      sshfs = final.symlinkJoin {
        name = "sshfs-no-hanging";
        paths = [ prev.sshfs ];
        nativeBuildInputs = [ final.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/sshfs --add-flags "-o ServerAliveInterval=5"
        '';
      };
    }
  );

  environment.systemPackages = [ pkgs.sshfs ];

  programs.zsh.shellAliases.ssh-forget = "ssh -o UserKnownHostsFile=/dev/null";

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.hyprland.windowRules."gnome-keyring-passphrase-prompt" = {
      matchers.class = "gcr-prompter";
      params.stay_focused = true;
      params.no_screen_share = true;
    };
  };

  ns.persistence.files = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
  ];

  ns.persistenceHome.directories = singleton {
    directory = ".ssh";
    mode = "0700";
  };

  ns.persistenceAdminHome.directories = mkIf (username != adminUsername) (singleton {
    directory = ".ssh";
    mode = "0700";
  });
}
