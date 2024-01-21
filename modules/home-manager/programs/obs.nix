{ lib, config, ... }:
let
  cfg = config.modules.programs.obs;
in
lib.mkIf cfg.enable {
  # The folders in this directory are OBS profiles which can be
  # imported/exported in OBS
  programs.obs-studio = {
    enable = true;
  };

  # For P2P wireguard screensharing use
  # srt://10.0.0.2:5201?mode=listener&latency=30000 as the stream address

  impermanence.directories = [
    ".config/obs-studio"
  ];
}
