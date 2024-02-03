lib:
let
  inherit (lib) mkMerge mkIf;
in
{
  mkIfElse = p: yes: no: mkMerge [
    (mkIf p yes)
    (mkIf (!p) no)
  ];

  homeConfig = args: args.outputs.nixosConfigurations.${args.hostname}.config.home-manager.users.${args.username};

  # Get list of all nix files and directories in path for easy importing
  scanPaths = path:
    builtins.map
      (f: (path + "/${f}"))
      (builtins.attrNames
        (lib.attrsets.filterAttrs
          (
            path: _type:
              (_type == "directory")
              || (
                (path != "default.nix")
                && (lib.strings.hasSuffix ".nix" path)
              )
          )
          (builtins.readDir path)));
}
