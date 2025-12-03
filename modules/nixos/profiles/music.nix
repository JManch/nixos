{ lib, config }:
let
  inherit (config.${lib.ns}.hardware.file-system) mediaDir;
in
{
  asserts = [
    (mediaDir != null)
    "Music profile requires 'mediaDir' to be set"
  ];

  ns.services.slskd.enable = true;
  ns.services.navidrome.enable = true;
  ns.programs.beets.enable = true;

  ns.backups."music" = {
    backend = "rclone";
    paths = [ "${lib.removePrefix "/persist" mediaDir}/music" ];

    notifications = {
      failure.config = {
        discord.enable = true;
        discord.var = "MUSIC";
      };

      success = {
        enable = true;
        config = {
          discord.enable = true;
          discord.var = "MUSIC";
        };
      };
    };

    timerConfig = {
      OnCalendar = "Sun *-*-* 8:00:00";
      Persistent = false;
    };

    backendOptions = {
      remote = "filen";
      mode = "sync";
      remotePaths."${lib.removePrefix "/persist" mediaDir}/music" = "music";
      flags = [ "--bwlimit 5M" ];
      check = {
        # Filen uses a case-insensitive file system so syncs can break if we change the
        # case of local directory names. Basically results in every backup run
        # attempting to re-upload the "renamed" directory with the remote directory
        # never changing.

        # Enabling checks allows us to detect when this happens so we can manually
        # intervene and fix it. A proper solution would be to use --track-renames but
        # it seems like the filen rclone implementation does not support move
        # operations: `PostV3FileMove: response error: Cannot move this file.
        # cannot_move_this_file : can't move object - incompatible remotes`
        enable = true;
        flags = [ "--size-only" ];
      };
    };
  };
}
