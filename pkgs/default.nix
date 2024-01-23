{ pkgs ? import <nixpkgs> { } }: rec {
  pomo = pkgs.callPackage ./pomo.nix { };
}
