{ pkgs, config }:
{
  home.packages = [ pkgs.claude-code ];

  home.sessionVariables."CLAUDE_CONFIG_DIR" = "${config.xdg.configHome}/claude";

  ns.persistence.directories = [ ".config/claude" ];
}
