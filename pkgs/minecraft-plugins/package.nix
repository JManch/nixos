{
  lib,
  pkgs,
}:
let
  inherit (lib) makeScope;
in
makeScope pkgs.newScope (
  final:
  let
    inherit (final) callPackage;
  in
  {
    vivecraft = callPackage ./vivecraft.nix { };
    squaremap = callPackage ./squaremap.nix { };
    aura-skills = callPackage ./aura-skills.nix { };
    levelled-mobs = callPackage ./levelled-mobs.nix { };
    tab-tps = callPackage ./tab-tps.nix { };
    luck-perms = callPackage ./luck-perms.nix { };
    gsit = callPackage ./gsit.nix { };
  }
)
