{ pkgs ? import <nixpkgs> { } }: rec {
  pomo = pkgs.callPackage ./pomo.nix { };
  modernx = pkgs.callPackage ./modernx.nix { };
}
