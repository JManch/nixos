{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.core) home-manager device;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = device.type != "laptop";
  };

  ns.userPackages = [
    (
      assert lib.assertMsg (pkgs.bluetui.version == "0.6") "Remove bluetui override";
      pkgs.bluetui.overrideAttrs rec {
        version = "0.7.2";

        src = pkgs.fetchFromGitHub {
          owner = "pythops";
          repo = "bluetui";
          rev = "v${version}";
          hash = "sha256-qryBx0Lezg98FzfAFZR6+j7byJTW7hMbGmKIQMkciec=";
        };

        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          inherit src;
          hash = "sha256-CijMGqsfyoUV8TSy1dWUR//PCySgkxKGuhUMHp4Tn48=";
        };
      }
    )
  ];

  ns.hm = mkIf home-manager.enable {
    xdg.desktopEntries.bluetui = mkIf config.${ns}.hmNs.desktop.enable {
      name = "Bluetui";
      genericName = "Bluetooth Manager";
      exec = "xdg-terminal-exec --title=bluetui --app-id=bluetui bluetui";
      terminal = false;
      type = "Application";
      icon = "preferences-bluetooth";
      categories = [ "System" ];
    };

    ${ns}.desktop.hyprland.settings.windowrule = [
      "float, class:^(bluetui)$"
      "size 60% 50%, class:^(bluetui)$"
      "center, class:^(bluetui)$"
    ];
  };

  ns.persistence.directories = [ "/var/lib/bluetooth" ];
}
