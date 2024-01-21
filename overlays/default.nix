{ inputs
, outputs
, ...
}:
let
  lib = inputs.nixpkgs.lib;
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

    # https://github.com/flightlessmango/MangoHud/issues/444
    mangohud = addPatches prev.mangohud [ ./mangoHud.diff ];

    waybar = addPatches prev.waybar [ ./waybarTraySpacingFix.diff ];

    amdgpu_top = prev.amdgpu_top.overrideAttrs (oldAttrs: {
      postInstall = oldAttrs.postInstall + ''
        substituteInPlace $out/share/applications/amdgpu_top.desktop \
          --replace "Name=AMDGPU TOP (GUI)" "Name=AMDGPU Top"
      '';
    });

    spotify = prev.spotify.overrideAttrs (oldAttrs: {
      postInstall = ''
        rm "$out/share/applications/spotify.desktop"
      '';
    });

    # Change notification priority and make notifications replace themselves
    spotify-player = addPatches prev.spotify-player [ ./spotifyPlayerNotifs.diff ];

    # Commit with new feature https://github.com/Gustash/Hyprshot/pull/19
    hyprshot = prev.hyprshot.overrideAttrs (oldAttrs: {
      src = final.fetchFromGitHub {
        owner = "Gustash";
        repo = "Hyprshot";
        rev = "36dbe2e6e97fb96bf524193bf91f3d172e9011a5";
        hash = "sha256-n1hDJ4Bi0zBI/Gp8iP9w9rt1nbGSayZ4V75CxOzSfFg=";
      };
    });

  };
}
