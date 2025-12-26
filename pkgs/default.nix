self: lib: pkgs:
let
  inherit (pkgs) callPackage;
  sources = import ../npins;
  args = { inherit sources; };
in
{
  # Npins managed
  modernx = callPackage ./modernx.nix args;
  beammp-server = callPackage ./beammp-server args;
  ctrld = callPackage ./ctrld.nix args;
  beammp-launcher = callPackage ./beammp-launcher.nix args;
  hyprpy = pkgs.python3Packages.callPackage ./hyprpy.nix args;
  soularr = pkgs.python3Packages.callPackage ./soularr.nix args;
  jellyfin-plugin-listenbrainz = callPackage ./jellyfin-plugin-listenbrainz args;
  filen-rclone = callPackage ./filen-rclone.nix args;
  frigate-blueprint = callPackage ./frigate-blueprint.nix args;
  thermal-comfort = pkgs.home-assistant.python.pkgs.callPackage ./thermal-comfort.nix args;
  thermal-comfort-icons = callPackage ./thermal-comfort-icons.nix args;
  heatmiser = pkgs.home-assistant.python.pkgs.callPackage ./heatmiser.nix args;
  daikin-onecta = pkgs.home-assistant.python.pkgs.callPackage ./daikin-onecta.nix args;
  # Because both `prev.callPackage` and `final.callPackage` always pass `final`
  # packages as arguments we need to manually pass in the `prev` brightnessctl
  # here to avoid infinite recursion
  # https://discourse.nixos.org/t/why-does-prev-callpackage-use-packages-from-final/25263
  brightnessctl = callPackage ./brightnessctl.nix (args // { inherit (pkgs) brightnessctl; });
  slskd-stats = pkgs.python3Packages.callPackage ./slskd-stats.nix args;
  yt-dlp = callPackage ./yt-dlp.nix args;
  comick-downloader = pkgs.python3Packages.callPackage ./comick-downloader.nix args;
  qobuz-dl = pkgs.python3Packages.callPackage ./qobuz-dl.nix args;

  # Manual
  advanced-camera-card = callPackage ./advanced-camera-card.nix { };
  multiviewer = callPackage ./multiviewer.nix { };

  # Other
  bootstrap-kit = callPackage ./bootstrap-kit.nix { inherit (self.inputs) nix-resources; };
  kobo-dither-cbz = callPackage ./kobo-dither-cbz { };
  microfetch = lib.${lib.ns}.addPatches pkgs.microfetch [ "microfetch-icon.patch" ];
  resample-flacs = callPackage ./resample-flacs.nix { };
  nvim =
    (import ./nvim {
      inherit self pkgs sources;
    }).neovim;
}
// import ./installers lib self pkgs
