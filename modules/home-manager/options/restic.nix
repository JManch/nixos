{ lib, username, ... }:
let
  inherit (lib) mkOption types mapAttrs' nameValuePair;
in
{
  options.backups = mkOption {
    type = types.attrs;
    default = { };
    apply = v: mapAttrs'
      (name: value: nameValuePair "home-${name}" (value // {
        paths = map (path: "/home/${username}/${path}") value.paths;
        exclude = map (path: "/home/${username}/${path}") value.exclude;
      }))
      v;
    description = ''
      Attribute set of Restic backups matching the upstream module backups
      options.
    '';
  };
}
