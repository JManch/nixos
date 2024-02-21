{ pkgs ? import <nixpkgs> { } }:
{
  pomo = pkgs.callPackage ./pomo.nix { };
  modernx = pkgs.callPackage ./modernx.nix { };
  filen-desktop = pkgs.callPackage ./filen-desktop.nix { };
}
