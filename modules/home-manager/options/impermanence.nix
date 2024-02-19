{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  # Custom persistence options for home-manager so that we can set the NixOS
  # persistence config from home-manager
  options.persistence = {
    directories = mkOption {
      type = with types; listOf (coercedTo str (d: { directory = d; }) attrs);
      default = [ ];
      example = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
      ];
      description = "Directories relative to home to bind mount in persistent storage";
    };

    files = mkOption {
      type = with types; listOf (coercedTo str (f: { file = f; }) attrs);
      default = [ ];
      example = [
        ".screenrc"
      ];
      description = "Files relative to home to bind mount in persistent storage";
    };
  };
}
