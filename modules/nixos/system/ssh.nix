{ lib
, pkgs
, self
, config
, username
, hostname
, adminUsername
, ...
}:
let
  inherit (lib) mkIf mapAttrs mkVMOverride utils optional getExe';
  cfg = config.modules.system.ssh;
in
{
  services.openssh = mkIf cfg.enable {
    enable = true;

    # Some devices are weird with port 22
    ports = [ 22 2222 ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ adminUsername ];
    };

    hostKeys = [{
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  users.users.${adminUsername}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDU68qiZQoWPMKZwaNu1CJikH0t4bV8OgjpOkpj6AwPW joshua@pixelbook"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPV7Ay4E3moAYtBDsVlSaIWHm1wabZU+qLnllAZdQibc joshua@pixel5"
  ];

  programs.ssh = {
    startAgent = true;
    agentTimeout = "1h";
    pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];

    knownHosts = (mapAttrs
      (host: _: {
        publicKeyFile = ../../../hosts/${host}/ssh_host_ed25519_key.pub;
        extraHostNames = ([ "${host}.lan" ] ++ optional (host == hostname) "localhost");
      })
      (utils.hosts self))
    // {
      "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      "joshua-pixel-5.lan".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOywqvmr4U7iEPwXCe5ZILFCapiplnvf/gU11++Aw2Y2";
      # WARN: Due to a bug in openssl https://security.stackexchange.com/a/267767 I have to use RSA key
      "router.lan".publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC1yUzmIm9tTBchHjSfRvSUvEzwT3dH09WI7Z+WW+CcjJ1MtYtjVVERRw2aRTD904sCkXNURSsGXdSrRP35k9Lz8ghMlplX4SPg4JwjJCFOuaqRQO6yeZ4kmvayuTE/g/ISlvvZWHQwVvQ1TYLXe0Zwz6RWNDjG9AqGkM6cpXGUdNxfRk2bB6pzrLBg7h+1zdQV/+NREbl9exIXlznIz0a4MGbJKvv3i0aJCB35kFeAcicDecDBtqfVzEmDtyNOxjtNj6FQXvzmJWmJGLEJkS8rlNI2hnjACQIS7z4tKHH/EN6QtzQyQ7yHtTGTS0O46wn8YHVVvEvR2w2hIhSMKtR3Km0NVJ5+9UnqJ72V7ppvKQngBeULIiLNO4vfuy9G52UqbSkp/qV+JaHTpHO/H51KSNNN/NPe6GO2mSoC4PcnClHsU2gEu92I5qjBp0FTNNlZJ3RxUp7MrseCVnZbl4CDCgSy6zG9zmlanGRo2LmbAdnK+8LEmUDYAIN01J3d4G+Hge7jWfEl6IVmlVoUDhW2LDqDLdza2sU6PTP3zriN+d+5LcaRWwQbJfCarSA7H3KmT3DVj39x+v/+Oo604qjfZl4OHSD7n8K9/ViSnu8VDL7rVoALkEH8caRCAjvctU3JyjyQTGwFv2NnV6LU7HGZNY1YJylvnSaRMfygI92qpQ==";
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

  persistenceAdminHome.directories = mkIf (username != adminUsername) [{
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
