{ lib, pkgs }:
let
  inherit (pkgs) callPackage;
in
{
  # WARN: Due to https://github.com/NixOS/nix/issues/9346 we cannot include
  # this in our flakes output packages as it breaks commands like `nix flake
  # check`. When the issue is fixed we can add it back to the main package set.
  minecraft-plugins = lib.recurseIntoAttrs {
    vivecraft = callPackage ./vivecraft.nix { };
    squaremap = callPackage ./squaremap.nix { };
    aura-skills = callPackage ./aura-skills.nix { };
    levelled-mobs = callPackage ./levelled-mobs.nix { };
    tab-tps = callPackage ./tab-tps.nix { };
    luck-perms = callPackage ./luck-perms.nix { };
    gsit = callPackage ./gsit.nix { };
  };
}
