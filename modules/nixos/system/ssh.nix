{ lib
, config
, outputs
, username
, hostname
, ...
}:
let
  inherit (lib) mapAttrs optional;
in
{
  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = config.modules.system.ssh.allowPasswordAuth;
      PermitRootLogin = "no";
    };

    hostKeys = [{
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  users.users.${username} = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    ];
  };

  programs.ssh = {
    startAgent = true;
    agentTimeout = "1h";
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];

    # TODO: Make this configurable. i.e. don't allow certain hosts
    # TODO: Don't store host public keys in .nix files
    knownHosts = (mapAttrs
      (host: _: {
        publicKey = "${(import ../../../hosts/${host}/key.nix).key}";
        extraHostNames = (optional (host == hostname) "localhost");
      })
      outputs.nixosConfigurations)
    // { "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"; };
  };

  security.pam.sshAgentAuth = {
    enable = true;
    authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
  };

  persistence.files = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
  ];

  persistenceHome.directories = [{
    directory = ".ssh";
    mode = "0700";
  }];
}
