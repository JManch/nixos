{ pkgs }:
{
  vivecraft = pkgs.callPackage ./vivecraft.nix { };
  squaremap = pkgs.callPackage ./squaremap.nix { };
  aura-skills = pkgs.callPackage ./aura-skills.nix { };
  levelled-mobs = pkgs.callPackage ./levelled-mobs.nix { };
  tab-tps = pkgs.callPackage ./tab-tps.nix { };
  luck-perms = pkgs.callPackage ./luck-perms.nix { };
  gsit = pkgs.callPackage ./gsit.nix { };
}
