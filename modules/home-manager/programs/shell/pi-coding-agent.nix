{
  lib,
  pkgs,
  config,
}:
{
  # Unfortunately pi stores state in settings.json so we cannot configure declaractively. Setup is pretty simple though:
  # pi install npm:pi-llama-cpp
  # Add `"llamaServerUrl": "https://llm.<fqDomain>"` to settings.json

  home.packages = [
    # https://discourse.nixos.org/t/pi-coding-agent-how-to-install-npm-extensions/77030
    (pkgs.symlinkJoin {
      name = "pi-coding-agent";
      buildInputs = [ pkgs.makeWrapper ];
      paths = [ pkgs.pi-coding-agent ];
      postBuild = ''
        wrapProgram $out/bin/pi \
          --set NPM_CONFIG_PREFIX ${config.xdg.configHome}/pi/npm/ \
          --set PI_CODING_AGENT_DIR ${config.xdg.configHome}/pi \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.nodejs_latest
            ]
          }
      '';
    })
  ];

  ns.persistence.directories = [ ".config/pi" ];
}
