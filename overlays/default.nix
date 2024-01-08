{ inputs
, outputs
, ...
}:
let
  addPatches = pkg: patches: pkg.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ patches;
  });
in
{
  modifications = final: prev: {

    eza = prev.eza.overrideAttrs (oldAttrs: rec {
      version = "0.10.7";
      src = final.fetchFromGitHub {
        owner = "eza-community";
        repo = "eza";
        rev = "v${version}";
        hash = "sha256-f8js+zToP61lgmxucz2gyh3uRZeZSnoxS4vuqLNVO7c=";
      };

      cargoDeps = oldAttrs.cargoDeps.overrideAttrs (prev.lib.const {
        name = "eza-vendor.tar.gz";
        inherit src;
        outputHash = "sha256-OBsXeWxjjunlzd4q1B1NJTm8MrIjicep2KIkydACKqQ=";
      });
    });

    vscode-extensions = final.lib.recursiveUpdate prev.vscode-extensions {
      ms-vsliveshare.vsliveshare = final.vscode-utils.extensionFromVscodeMarketplace {
        name = "vsliveshare";
        publisher = "ms-vsliveshare";
        version = "1.0.5900";
        sha256 = "sha256-syVW/aS2ppJjg4OZaenzGM3lczt+sLy7prwsYFTDl9s=";
      };
    };

  };
}
