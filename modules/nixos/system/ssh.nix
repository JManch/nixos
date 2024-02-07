{ lib
, config
, outputs
, username
, hostname
, ...
}:
let
  hosts = builtins.attrNames outputs.nixosConfigurations;
in
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = config.modules.system.ssh.allowPasswordAuth;
      PermitRootLogin = "no";
    };
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    # TODO: Make this configurable. i.e. don't allow certain hosts
    knownHosts = builtins.mapAttrs
      (host: _: {
        publicKey = "${(import ../../../hosts/${host}/key.nix).key}";
        extraHostNames = (lib.lists.optional (host == hostname) "localhost");
      })
      outputs.nixosConfigurations;
  };

  users.users.${username} = {
    # TODO: Make this better. Maybe store public keys in file.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    ];
  };

  programs.ssh = {
    startAgent = true;
    agentTimeout = "1h";
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];
  };

  security.pam.sshAgentAuth = {
    enable = true;
    authorizedKeysFiles = [
      "/etc/ssh/authorized_keys.d/%u"
    ];
  };

  environment.persistence."/persist".users.${username}.directories =
    [
      {
        directory = ".ssh";
        mode = "0700";
      }
    ];
}
