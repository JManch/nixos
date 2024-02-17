{ lib
, ...
}:
let
  inherit (lib) mkOption types;
in
{
  # Custom impermanence options for home-manager so that we can use the nixos
  # impermanence config from home-manager
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
      description = ''
        Home directories to bind mount to persistent storage.
      '';
    };
    files = mkOption {
      type = with types; listOf (coercedTo str (f: { file = f; }) attrs);
      default = [ ];
      example = [
        ".screenrc"
      ];
      description = ''
        Home files that should be stored in persistent storage.
      '';
    };
  };
}
