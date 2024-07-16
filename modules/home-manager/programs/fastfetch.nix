{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.programs.fastfetch;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.fastfetch ];

  programs.zsh.shellAliases = {
    neofetch = "fastfetch";
  };

  xdg.configFile."fastfetch/config.jsonc".text = # jsonc
    ''
      {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "modules": [
          "title",
          "separator",
          {
            "type": "os",
            "format": "{3} {12}"
          },
          {
            "type": "host",
            "format": "{/2}{-}{/}{2}{?3} {3}{?}"
          },
          "kernel",
          "uptime",
          "packages",
          "shell",
          {
            "type": "display",
            "compactType": "original",
            "key": "Resolution"
          },
          "de",
          "wm",
          "wmtheme",
          "icons",
          "cursor",
          "terminal",
          {
            "type": "terminalfont",
            "format": "{/2}{-}{/}{2}{?3} {3}{?}"
          },
          "cpu",
          {
            "type": "gpu",
            "key": "GPU"
          },
          {
            "type": "memory",
            "format": "{/1}{-}{/}{/2}{-}{/}{} / {}"
          },
          "disk",
        ]
      }
    '';
}
