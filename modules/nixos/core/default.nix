{ lib, pkgs, username, ... }:
let
  inherit (lib) utils mkOption mkEnableOption types;
in
{
  imports = utils.scanPaths ./.;

  options.modules.core = {
    homeManager.enable = mkEnableOption "Home Manager";
    autoUpgrade = mkEnableOption "auto upgrade";

    username = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = username;
      description = ''
        Used for getting the username of a given nixosConfiguration.
      '';
    };

    loadNixResourcesKey = mkOption {
      type = types.lines;
      internal = true;
      readOnly = true;
      default = /*bash*/ ''
        tmp_key=$(mktemp)
        ssh_dir="/home/${username}/.ssh"
        flake="/home/${username}/.config/nixos"
        if [ ! -d $flake ]; then
          echo "Flake does not exist locally so using remote from github"
          flake="github:JManch/nixos"
        fi

        ${utils.exitTrapBuilder}
        reset_key() {
          if [[ -f "$tmp_key" && -s "$tmp_key" ]]; then
            mv "$tmp_key" "$ssh_dir/id_ed25519"
          fi
          rm -f "$tmp_key"
        }
        add_exit_trap reset_key

        # On users that are not my own, temporarily copy the nix-resources key
        # to .ssh/ed25519. This is because there's no way (that I'm aware of)
        # to specify the SSH key that nixos-rebuild uses for authentication. My
        # own user does not need this workaround because my main ssh key gives
        # access.
        # shellcheck disable=SC2050
        if [ "${username}" != "joshua" ]; then
          if [ -f "$ssh_dir/id_ed25519" ]; then
            mv "$ssh_dir/id_ed25519" "$tmp_key"
          fi
          cp "$ssh_dir/id_nix-resources" "$ssh_dir/id_ed25519"
        fi
      '';
      description = ''
        Bash script for temporarily replacing the user's primary ssh key with
        my nix-resources access key. This enables access to my private
        nix-resources flake on hosts that do not have my main ssh key
        installed. The script also sets a $flake variable for convenience.
      '';
    };
  };

  config = {
    environment.systemPackages = [
      pkgs.git
    ];

    security.sudo.extraConfig = "Defaults lecture=never";
    time.timeZone = "Europe/London";
    system.stateVersion = "23.05";

    programs.zsh.enable = true;

    environment.sessionVariables = {
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
  };
}
