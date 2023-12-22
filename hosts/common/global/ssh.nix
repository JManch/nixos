{
  inputs,
  lib,
  config,
  ...
}: let
  # Not sure if I actually need this, needs testing
  hasOptinPersistence = config.environment.persistence ? "/persist";
in {
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
    hostKeys = [
      {
        path = "${lib.optionalString hasOptinPersistence "/persist"}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  programs.ssh = {
    startAgent = true;
    agentTimeout = "1h";
    pubkeyAcceptedKeyTypes = ["ssh-ed25519"];
  };

  security.pam.enableSSHAgentAuth = true;
}
