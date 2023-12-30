{ lib, config, ... }:
let
  cfg = config.modules.programs.btop;
in
lib.mkIf cfg.enable {
  programs.btop.enable = true;
}
