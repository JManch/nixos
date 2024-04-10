{ lib, config, inputs, ... }:
let
  cfg = config.modules.hardware.fanatec;
in
lib.mkIf cfg.enable
{
  boot = {
    kernelModules = [ "hid-fanatec" ];
    extraModulePackages = [
      (config.boot.kernelPackages.callPackage "${inputs.nix-resources}/pkgs/hid-fanatecff.nix" { })
    ];
  };

  programs.zsh.interactiveShellInit = /*bash*/ ''

    fanatec-load-profile() {
      if [ -z "$1" ]; then
        echo "Usage: fanatec-load-profile (beamng|assetto corsa)"
        return 1
      fi

      sens=1080
      if [ "$1" = "beamng" ]; then sens=2520; fi

      dir="/sys/module/hid_fanatec/drivers/hid:fanatec/0003:0EB7:0020.0015/ftec_tuning/0003:0EB7:0020.0015"
      echo "$sens" | sudo tee "$dir/SEN"
      echo 70 | sudo tee "$dir/FEI"
      echo 1 | sudo tee "$dir/NDP"
      echo 0 | sudo tee "$dir/NFR"
      echo 0 | sudo tee "$dir/NIN"
      echo 2 | sudo tee "$dir/INT"
    }

  '';
}
