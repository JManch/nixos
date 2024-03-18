{ lib
, pkgs
, config
, outputs
, username
, hostname
, ...
}:
let
  inherit (lib) mapAttrs mkVMOverride utils optional getExe';
  cfg = config.modules.system.ssh;
in
{
  services.openssh = {
    enable = cfg.enable;

    # Some devices are weird with port 22
    ports = [ 22 2222 ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AllowUsers = [ "root" username ];
    };

    hostKeys = [{
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    ];
  };

  users.users.${username} = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDU68qiZQoWPMKZwaNu1CJikH0t4bV8OgjpOkpj6AwPW joshua@pixelbook"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPV7Ay4E3moAYtBDsVlSaIWHm1wabZU+qLnllAZdQibc joshua@pixel5"
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
      (utils.hosts outputs))
    // {
      "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  programs.zsh = {
    shellAliases = {
      "ssh-forget" = "ssh -o UserKnownHostsFile=/dev/null";
    };

    interactiveShellInit =
      let
        sshAdd = getExe' pkgs.openssh "ssh-add";
      in
        /*bash*/ ''

      ssh-add-quiet() {
        keys=$(${sshAdd} -l)
        if [[ "$keys" == "The agent has no identities." ]]; then
          ${sshAdd}
        fi
      }

    '';
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

  virtualisation.vmVariant = {
    services.openssh = {
      ports = mkVMOverride [ 22 ];

      # Root access needed for copying SSH keys to VM for secret decryption
      settings = {
        PermitRootLogin = mkVMOverride "yes";
        AllowUsers = mkVMOverride null;
      };
    };

    users.users.root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
      ];
    };
  };
}
