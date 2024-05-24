{ pkgs, lib }:
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
  beammp-server = pkgs.callPackage ./beammp-server { };
  heatmiser = pkgs.home-assistant.python.pkgs.callPackage ./heatmiser.nix { };

  # WARN: Due to https://github.com/NixOS/nix/issues/9346 this breaks my
  # flake's output with commands like `nix flake check`
  minecraft-plugins = lib.recurseIntoAttrs {
    vivecraft = pkgs.callPackage ./minecraft-plugins/vivecraft.nix { };
    squaremap = pkgs.callPackage ./minecraft-plugins/squaremap.nix { };
    aura-skills = pkgs.callPackage ./minecraft-plugins/aura-skills.nix { };
    levelled-mobs = pkgs.callPackage ./minecraft-plugins/levelled-mobs.nix { };
    tab-tps = pkgs.callPackage ./minecraft-plugins/tab-tps.nix { };
    luck-perms = pkgs.callPackage ./minecraft-plugins/luck-perms.nix { };
    gsit = pkgs.callPackage ./minecraft-plugins/gsit.nix { };
  };
}
