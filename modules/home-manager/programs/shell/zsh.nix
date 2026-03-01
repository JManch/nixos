{
  lib,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib) mkIf singleton;
in
{
  enableOpt = false;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    dotDir = "${config.xdg.configHome}/zsh";

    plugins = singleton {
      name = "zsh-vi-mode";
      file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      src = pkgs.zsh-vi-mode;
    };

    syntaxHighlighting = {
      enable = true;
      styles = {
        path = "none";
        path_prefix = "none";
        unknown-token = "fg=red";
        precommand = "fg=green";
      };
    };

    history = {
      path = "${config.xdg.stateHome}/zsh/zsh_history";
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      size = 500000;
    };

    shellAliases = {
      cat = "bat -pp --theme=base16";
      reload = "exec zsh";
      dupe =
        mkIf config.${lib.ns}.desktop.enable
          "app2unit -t service -T -e zsh '-c' \"cd '$(pwd)'; zsh -i\"";
    };

    envExtra =
      mkIf (osConfig != null) # bash
        ''
          # Fix for `nix develop` making our default shell bash
          export SHELL=/run/current-system/sw/bin/zsh
        '';

    initContent =
      lib.mkBefore # bash
        ''
          function set_term_title() {
            print -Pn "\e]2;$1\a"
          }

          local -a zellij_cwd_cmds=(ls ll la lll cd pwd)
          zellij_show_cwd=0

          function precmd_zellij_tab_name() {
            if (( zellij_show_cwd )); then
              local dir="''${PWD##*/}"
              [[ "$PWD" == "$HOME" ]] && dir="~"
              zellij action rename-tab "''${dir}/" &>/dev/null &!
              zellij_show_cwd=0
            fi
          }

          function preexec_update_title() {
            if [[ -n $ZELLIJ ]]; then
              local -a cmd=(''${(z)1})
              local process_name=$cmd[1]
              if [[ -n $process_name ]]; then
                if (( ''${zellij_cwd_cmds[(Ie)$process_name]} )); then
                  zellij_show_cwd=1
                else
                  zellij_show_cwd=0
                  command zellij action rename-tab "$process_name" &>/dev/null &!
                fi
              fi
            else
              set_term_title "%~: $1"
            fi
          }

          add-zsh-hook preexec preexec_update_title
          [[ -n $ZELLIJ ]] && add-zsh-hook precmd precmd_zellij_tab_name

          function zvm_config() {
            ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
            ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
            ZVM_KEYTIMEOUT=0.6
            # Load the plugin straight away so we don't have to deal with keybind
            # order for things like fzf
            ZVM_INIT_MODE=sourcing
          }

          function jump_end_of_line() {
            zvm_navigation_handler $
          }

          function jump_start_of_line() {
            zvm_navigation_handler '^'
          }

          function zvm_after_lazy_keybindings() {
            zvm_define_widget jump_start_of_line
            zvm_define_widget jump_end_of_line
            zvm_bindkey vicmd 'H' jump_start_of_line
            zvm_bindkey vicmd 'L' jump_end_of_line
            zvm_bindkey visual 'H' jump_start_of_line
            zvm_bindkey visual 'L' jump_end_of_line
          }

          setopt interactivecomments

          reboot() {
            read -q "REPLY?Are you sure you want to reboot? (y/N)"
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              command reboot
            fi
          }

          edit-home-file() {
            if [ -z "$1" ] || [ ! -e "$1" ]; then
              echo "Usage: edit-home-file <file_path>"
              return 1
            fi

            file_path="$1"
            dir_path=$(dirname "$file_path")
            file_name=$(basename -- "$file_path")

            copy_path="$dir_path/''${file_name%.*}.copy.''${file_name##*.}"
            cat "$file_path" > "$copy_path" && rm "$file_path" && mv "$copy_path" "$file_path"
            $EDITOR "$file_path"
          }
        '';
  };

  ns.persistence.directories = [
    ".config/zsh" # for zcompdump
    ".local/state/zsh"
    ".cache/zsh"
  ];
}
