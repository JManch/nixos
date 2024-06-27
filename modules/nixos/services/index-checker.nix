{ lib
, pkgs
, self
, config
, ...
}:
let
  inherit (lib) mkIf getExe;
  cfg = config.modules.services.index-checker;
  shoutrrr = getExe self.packages.${pkgs.system}.shoutrrr;

  pythonScript = pkgs.writers.writePython3 "index-checker"
    {
      libraries = [ pkgs.python3Packages.google-search-results ];
    } /*python*/ ''
    import os
    from serpapi import GoogleSearch


    if __name__ == "__main__":
        query = f'site:{os.environ["URL"]}'
        params = {
            'q': query,
            'engine': 'google',
            'api_key': os.environ['API_KEY']
        }
        search = GoogleSearch(params)
        indexed_results = search.get_dict().get('organic_results', [])
        if len(indexed_results) == 0:
            exit(1)
        print(indexed_results)
        exit(0)
  '';
in
mkIf cfg.enable
{
  systemd.services.index-checker = {
    description = "Google site indexed checker";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.PYTHONUNBUFFERED = "1";

    serviceConfig = {
      EnvironmentFile = config.age.secrets.indexCheckerVars.path;
      StateDirectory = "index-checker";
      ExecStart = getExe (pkgs.writeShellApplication {
        name = "index-checker";
        runtimeInputs = [ pkgs.coreutils self.packages.${pkgs.system}.shoutrrr ];
        text = /*bash*/ ''
          set +e
          send_notif() {
            ${shoutrrr} send \
              --url "$DISCORD_AUTH" \
              --title "Index Status Changed" \
              --message "$1"
          }

          while true
          do
            ${pythonScript}
            status=$?
            if [[ $status -eq 0 && ! -e /var/lib/index-checker/indexed ]]; then
              touch /var/lib/index-checker/indexed
              send_notif "Yay $URL is now indexed!"
            elif [[ $status -ne 0 && -e /var/lib/index-checker/indexed ]]; then
              rm -f /var/lib/index-checker/indexed
              send_notif "Nooo $URL is no longer indexed"
            fi
            sleep 8h
          done
        '';
      });
    };
  };

  persistence.directories = [ "/var/lib/index-checker" ];
}
