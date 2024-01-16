let
  joshua = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObU6Fxl5fshbiTZ53wkuvWT3lainInWSdfk/FXQYIxv joshua";
  ncase-m1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGmso00Sb3ab0dURSMJGAYN10OQQQ3VlPxHtNz092a8s root@ncase-m1";
  virtual = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIRMA3ZtwZr/w9QG7iFfWFFSCAIjxw0XSejZPGHdYCzW root@virtual";
  allHosts = [ ncase-m1 virtual ];
in
{
  # Editing
  # `agenix -e [file] -i [PATH_TO_REQUIRED_KEY]`

  # Rekeying
  # All of the private keys need to be provided when rekeying
  # `sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key -i /home/joshua/.ssh/joshua_ed25519 ...`

  "passwds/joshua.age".publicKeys = allHosts;
  "wireless-networks.age".publicKeys = allHosts;
  "nordvpn/token.age".publicKeys = allHosts;

  "syncthing/ncase-m1/cert.age".publicKeys = [ ncase-m1 ];
  "syncthing/ncase-m1/key.age".publicKeys = [ ncase-m1 ];
  "wireguard/ncase-m1/key.age".publicKeys = [ ncase-m1 ];

  # Home-manager secrets can only be decrypted by the "joshua" key
  "spotify.age".publicKeys = [ joshua ];
}
