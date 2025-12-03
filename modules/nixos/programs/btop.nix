{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns getExe;
  inherit (config.${ns}.core) device;
in
[
  {
    enableOpt = false;
    guardType = "first";
    conditions = [ "hmConfig.programs.shell.btop" ];

    # The CPU package power feature needs these capabilities
    # https://github.com/aristocratos/btop/pull/1227
    security.wrappers."btop" = {
      # we use a custom program name so that our home-manager wrapper (of the
      # setcap wrapper) has precendence in PATH
      program = "setcap-btop";
      owner = "root";
      group = "root";
      source = getExe pkgs.btop;
      capabilities = "cap_perfmon,cap_dac_read_search+ep";
    };
  }

  {
    nixpkgs.overlays = [
      (_: prev: {
        btop = prev.btop.override {
          cudaSupport = device.gpu.type == "nvidia";
          rocmSupport = device.gpu.type == "amd";
        };
      })
    ];
  }
]
