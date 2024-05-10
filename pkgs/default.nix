{ pkgs ? import <nixpkgs> { } }:
{
  pomo = pkgs.callPackage ./pomo.nix { };
  modernx = pkgs.callPackage ./modernx.nix { };
  filen-desktop = pkgs.callPackage ./filen-desktop.nix { };
  ctrld = pkgs.callPackage ./ctrld.nix { };
  frigate-hass-card = pkgs.callPackage ./frigate-hass-card.nix { };
  frigate-blueprint = pkgs.callPackage ./frigate-blueprint.nix { };
  shoutrrr = pkgs.callPackage ./shoutrrr.nix { };
  thermal-comfort = pkgs.callPackage ./thermal-comfort.nix { };
  thermal-comfort-icons = pkgs.callPackage ./thermal-comfort-icons.nix { };
  minecraft-plugins = import ./minecraft-plugins { inherit pkgs; };
}
