{ lib, ... }:
{
  ${lib.ns}.nix-on-droid = {
    uid = 10405;
    gid = 10405;
    ssh.server = {
      enable = true;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
      ];
    };
  };

  system.stateVersion = "24.05";
}
