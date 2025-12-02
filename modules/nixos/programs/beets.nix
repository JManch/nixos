{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns getExe singleton;
  inherit (config.${ns}.hardware.file-system) mediaDir;
in
{
  # Import new music with `beet import --timid --from-scratch /path/to/music`

  # WARN: When importing to replace an existing import, the "Remove old"
  # option does not remove the cover file so that has to be done manually
  # first to avoid a duplicate cover being added.

  # When picking a release prefer digital releases as they have the best
  # cover on musicbrainz

  # To change the musicbrainz release of an album first re-import with `beet
  # import --timid --library <query>` (use -s to target a single track) then
  # choose the correct musicbrainz release. For some reason not all metadata
  # gets updated after this so run `beet mbsync <query>`.
  ns.userPackages = [
    pkgs.${ns}.resample-flacs
    (pkgs.symlinkJoin {
      name = "beets-wrapped-config";
      paths = singleton (
        pkgs.python3Packages.beets.override {
          pluginOverrides = {
            replaygain.enable = true;
            autobpm.enable = true;
            fetchart.enable = true;
            embedart.enable = true;
            lyrics.enable = true;
            mbsync.enable = true;
            missing.enable = true;
            permissions.enable = true;
            unimported.enable = true;
            hook.enable = true;
          };
        }
      );
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild =
        let
          config = (pkgs.formats.yaml { }).generate "beets-config.yaml" {
            directory = "${mediaDir}/music";
            library = "${mediaDir}/music/library.db";
            paths.singleton = "$albumartist/Non-Album/$title";

            plugins = [
              "musicbrainz"
              "replaygain"
              "autobpm"
              "fetchart"
              "embedart"
              "lyrics"
              "mbsync" # provides command to fetch latest metadata from musicbrainz
              "missing"
              "permissions"
              "unimported"
              "hook"
            ];

            incremental = false; # creates unwanted state.pickel file
            autobpm.auto = true;
            lyrics.auto = true;
            asciify_paths = true;

            fetchart = {
              auto = true;
              sources = [
                "filesystem"
                { coverart = "release"; }
                { coverart = "releasegroup"; }
                "itunes"
                "albumart"
              ];
            };

            hook.hooks = singleton {
              event = "before_item_imported";
              command = "${
                getExe (
                  pkgs.writeShellApplication {
                    name = "beets-resample-flac";
                    runtimeInputs = [ pkgs.sox ];
                    text = ''
                      input_file="$1"
                      filename=$(basename "$input_file")

                      if [[ $filename != *.flac ]]; then
                        exit 0
                      fi

                      if [[ -f /tmp/beets-disable-resample ]]; then
                        echo "Beets resampling is disabled so skipping"
                        exit 0
                      fi

                      sample_rate=$(soxi -r "$input_file")
                      bitrate=$(soxi -b "$input_file")
                      tmp_file=$(mktemp -p /tmp "resample-flac-tmp.XXXXXX.flac")
                      trap 'rm -f "$tmp_file"' EXIT

                      if [[ $sample_rate -gt 44100 || $bitrate -gt 16 ]]; then
                        sox -G "$input_file" -b 16 --comment "" "$tmp_file" rate -v 44100
                        echo "Resampled $filename: $bitrate/''${sample_rate}Hz -> 16/44100Hz"
                      else
                        echo "Skipping $filename: $bitrate/''${sample_rate}Hz"
                        exit 0
                      fi

                      mv "$tmp_file" "$input_file"
                    '';
                  }
                )
              } \"{source}\"";
            };

            match = {
              # Always prefer digital releases
              max_rec.media = "medium";
              preferred.media = [ "Digital Media" ];
              ignored_media = [
                # Vinyl usually has bad cover art on musicbrainz
                "12\" Vinyl"
                "Vinyl"
              ];
            };

            # some release groups have lots of CD/vinyls
            musicbrainz.search_limit = 20;

            embedart = {
              auto = true;
              maxwidth = 600; # shrink album covers to a sensible size when embedding
              minwidth = 1000;
            };

            # some files may be owned by slskd:slskd
            permissions = {
              file = 666;
              dir = 777;
            };

            import = {
              write = true;
              move = true;
            };

            replaygain = {
              auto = true;
              backend = "ffmpeg";
              overwrite = true;
            };
          };
        in
        ''
          wrapProgram $out/bin/beet --add-flags "--config=${config}"
        '';
    })
  ];

}
