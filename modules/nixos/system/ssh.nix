{ lib
, config
, outputs
, username
, hostname
, ...
}:
let
  inherit (lib) mapAttrs optional;
  cfg = config.modules.system.ssh;
in
{
  services.openssh = {
    enable = cfg.enable;

    # Some devices are weird with port 22
    ports = [ 2222 ];

    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ username ];
    };

    hostKeys = [{
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  users.users.${username} = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDU68qiZQoWPMKZwaNu1CJikH0t4bV8OgjpOkpj6AwPW joshua@pixelbook"
    ];
  };

  programs.ssh = {
    startAgent = true;
    agentTimeout = "1h";
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];

    knownHosts = (mapAttrs
      (host: _: {
        publicKeyFile = ../../../hosts/${host}/ssh_host_ed25519_key.pub;
        extraHostNames = (optional (host == hostname) "localhost");
      })
      outputs.nixosConfigurations)
    // {
      "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
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
