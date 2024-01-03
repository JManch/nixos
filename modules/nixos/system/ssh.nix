{ config
, username
, ...
}:
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

  programs.ssh = {
    startAgent = true;
    agentTimeout = "1h";
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];
  };

  security.pam.enableSSHAgentAuth = true;

  environment.persistence."/persist".users.${username}.directories =
    [
      {
        directory = ".ssh";
        mode = "0700";
      }
    ];
}
