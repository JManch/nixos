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
    genAttrs
    mapAttrs
    hasAttr
    optionalAttrs
    mkOption
    types
    optional
    optionals
    singleton
    mkEnableOption
    ;
  inherit (config.${ns}.system) virtualisation;
  inherit (inputs.nix-resources.secrets) keys;
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

  services.openssh = mkIf cfg.server.enable {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
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

  users.users.root.openssh.authorizedKeys.keys = [ keys.personal ];

  users.users.${adminUsername}.openssh.authorizedKeys.keys = with keys; [
    personal
    pixel-9-personal
  ];

  programs.ssh = {
    startAgent = cfg.agent.enable;
    agentTimeout = "1h";
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];
    extraConfig = mkIf cfg.agent.enable ''
      AddKeysToAgent yes
    '';

    knownHosts =
      (mapAttrs (host: _: {
        publicKey = keys.${host};
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
        "github.com".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        "router.lan".publicKey = keys.router;
      };
  };

  environment.systemPackages = [ pkgs.sshfs ];

  programs.zsh.shellAliases.ssh-forget = "ssh -o UserKnownHostsFile=/dev/null";

  # WARN: For some reason enabling the agent on hosts where the primary user
  # does not have admin priviledges causes sudo commands to fail after `su
  # adminUser` with "pam_ssh_agent_auth: fatal: uid `adminUid`` attempted to
  # open an agent socket owned by uid `userUid`". I don't need the agent on
  # these hosts anyway so it's disabled by default.
  security.pam.sshAgentAuth = mkIf cfg.agent.enable {
    enable = true;
    authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
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
