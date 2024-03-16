{ nixpkgs, pkgs, ... }:
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  environment.systemPackages = with pkgs; [
    # nixos-anywhere needs rsync for transfering secrets
    rsync
    disko
    gitMinimal
    nvim
  ];

  # TODO: Figure out the install procedure using disko when inside the
  # installer and write a script for it

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    ];
  };
}
