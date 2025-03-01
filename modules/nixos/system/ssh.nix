{
  lib,
  cfg,
  self,
  config,
  username,
  hostname,
  adminUsername,
}:
let
  inherit (lib)
    ns
    mkIf
    mapAttrs
    optional
    singleton
    mkEnableOption
    ;
  inherit (config.${ns}.system) virtualisation;
in
{
  enableOpt = false;

  opts = {
    server.enable = mkEnableOption "SSH server";
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

  # Enable using this host as a build host in VMs
  networking.firewall.interfaces = mkIf virtualisation.libvirt.enable {
    virbr0.allowedTCPPorts = [ 22 ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
  ];

  users.users.${adminUsername}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDU68qiZQoWPMKZwaNu1CJikH0t4bV8OgjpOkpj6AwPW joshua@pixelbook"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPV7Ay4E3moAYtBDsVlSaIWHm1wabZU+qLnllAZdQibc joshua@pixel5"
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
        publicKeyFile = ../../../hosts/${host}/ssh_host_ed25519_key.pub;
        extraHostNames = ([ "${host}.lan" ] ++ optional (host == hostname) "localhost");
      }) (self.nixosConfigurations // self.nixOnDroidConfigurations))
      // {
        "github.com".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        # WARN: Due to a bug in openssl https://security.stackexchange.com/a/267767 I have to use RSA key
        "router.lan".publicKey =
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC1yUzmIm9tTBchHjSfRvSUvEzwT3dH09WI7Z+WW+CcjJ1MtYtjVVERRw2aRTD904sCkXNURSsGXdSrRP35k9Lz8ghMlplX4SPg4JwjJCFOuaqRQO6yeZ4kmvayuTE/g/ISlvvZWHQwVvQ1TYLXe0Zwz6RWNDjG9AqGkM6cpXGUdNxfRk2bB6pzrLBg7h+1zdQV/+NREbl9exIXlznIz0a4MGbJKvv3i0aJCB35kFeAcicDecDBtqfVzEmDtyNOxjtNj6FQXvzmJWmJGLEJkS8rlNI2hnjACQIS7z4tKHH/EN6QtzQyQ7yHtTGTS0O46wn8YHVVvEvR2w2hIhSMKtR3Km0NVJ5+9UnqJ72V7ppvKQngBeULIiLNO4vfuy9G52UqbSkp/qV+JaHTpHO/H51KSNNN/NPe6GO2mSoC4PcnClHsU2gEu92I5qjBp0FTNNlZJ3RxUp7MrseCVnZbl4CDCgSy6zG9zmlanGRo2LmbAdnK+8LEmUDYAIN01J3d4G+Hge7jWfEl6IVmlVoUDhW2LDqDLdza2sU6PTP3zriN+d+5LcaRWwQbJfCarSA7H3KmT3DVj39x+v/+Oo604qjfZl4OHSD7n8K9/ViSnu8VDL7rVoALkEH8caRCAjvctU3JyjyQTGwFv2NnV6LU7HGZNY1YJylvnSaRMfygI92qpQ==";
        "tom.friends".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILXXsn0Q4UzpMAnYa5b2TE5KxTeBjLy0ck4eIwekD93b";
      };
  };

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
