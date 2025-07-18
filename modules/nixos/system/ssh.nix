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
    attrValues
    singleton
    mkEnableOption
    ;
  inherit (config.${ns}.system) virtualisation;
  inherit (inputs.nix-resources.secrets) keys;
  inherit (config.${ns}.system) desktop;
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
    extraConfig = mkIf cfg.agent.enable ''
      AddKeysToAgent yes
    '';

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
        "github.com".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        "router.lan".publicKey = keys.misc.router;
      };
  };

  environment.systemPackages = [ pkgs.sshfs ];

  programs.zsh.shellAliases.ssh-forget = "ssh -o UserKnownHostsFile=/dev/null";

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
