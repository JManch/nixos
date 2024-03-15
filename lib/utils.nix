lib:
let
  inherit (lib) attrNames filterAttrs;
in
{
  homeConfig = args:
    args.outputs.nixosConfigurations.${args.hostname}.config.home-manager.users.${args.username};

  flakePkgs = args: flake: args.inputs.${flake}.packages.${args.pkgs.system};

  addPatches = pkg: patches: pkg.overrideAttrs
    (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ patches;
    });

  hosts = outputs: filterAttrs (host: v: (host != "installer")) outputs.nixosConfigurations;

  # Get list of all nix files and directories in path for easy importing
  scanPaths = path:
    map (f: (path + "/${f}"))
      (attrNames
        (filterAttrs
          (path: _type:
            (_type == "directory") || (
              (path != "default.nix")
              && (lib.strings.hasSuffix ".nix" path)
            )
          )
          (builtins.readDir path)));
}
