{
  lib,
  pkgs,
  args,
}:
{
  home.packages = [
    # Remove override once 1.7 releases
    ((lib.${lib.ns}.flakePkgs args "noita-entangled-worlds").default.overrideAttrs (
      final: prev: {
        version = "1.6.2";

        src = pkgs.fetchFromGitHub {
          owner = "intquant";
          repo = "noita_entangled_worlds";
          rev = "v${final.version}";
          hash = "sha256-DAGLpGo8K6qSfxMwTELSU9HLHRX2lp5qbmmq/tL08JM=";
        };

        cargoLock = null;

        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          inherit (final) src sourceRoot;
          hash = "sha256-VIOr/3inwP79756UD6JIImk7rOuiHK1QiZBoqW5cSTo=";
        };
      }
    ))

    (pkgs.writeShellApplication {
      name = "noita-switch-save";
      runtimeInputs = with pkgs; [ procps ];
      text = ''
        if pgrep -x "noita.exe" >/dev/null; then
          echo "Noita is running, close it first" >&2
          exit 1
        fi

        new_mode=$1
        if [[ $new_mode == "multiplayer" ]]; then
          current_mode="solo"
        elif [[ $new_mode == "solo" ]]; then
          current_mode="multiplayer"
        else
          echo "Usage: noita-switch-save solo|multiplayer" >&2
          exit 1
        fi

        save_path="$XDG_DATA_HOME/Steam/steamapps/compatdata/881100/pfx/drive_c/users/steamuser/AppData/LocalLow/Nolla_Games_Noita"
        if [[ ! -d $save_path ]]; then
          echo "Noita state dir '$save_path' does not exist" >&2
          exit 1
        fi

        if [[ ! -d "$save_path/save00_$new_mode" && -d "$save_path/save00" ]]; then
          echo "Save file '$new_mode' is already loaded" >&2
          exit 1
        fi

        if [[ -d "$save_path/save00_$current_mode" ]]; then
          echo "Current mode dir already exists, something is wrong" >&2
          exit 1
        fi

        mv "$save_path/save00" "$save_path/save00_$current_mode"
        mv "$save_path/save00_$new_mode" "$save_path/save00"
        echo "Successfully switched to save '$new_mode'"
      '';
    })
  ];

  categoryConfig = {
    steamAppIDs."Noita" = 881100;
    tearingExcludedClasses = [ "steam_app_881100" ]; # tearing lags cursor
  };

  ns.backups."noita" = {
    backend = "restic";
    paths = [
      ".local/share/Steam/steamapps/compatdata/881100/pfx/drive_c/users/steamuser/AppData/LocalLow/Nolla_Games_Noita"
    ];
  };

  ns.persistence.directories = [
    ".config/entangledworlds"
    ".local/share/entangledworlds"
  ];
}
