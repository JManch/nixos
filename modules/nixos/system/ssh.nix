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
  };

  users.users.${username} = {
    # Authorise all other hosts except our own
    openssh.authorizedKeys.keys = lib.lists.concatMap
      (
        host:
        if host == hostname then [ ] else
        [ "${(import ../../../hosts/${host}/key.nix).key}" ]
      )
      hosts;
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
