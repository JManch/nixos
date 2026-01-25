{
  scdl,
  sources,
  python3Packages,
  fetchPypi,
}:
(scdl.overrideAttrs (old: {
  inherit (sources.scdl) version;
  src = sources.scdl;
  propagatedBuildInputs = old.propagatedBuildInputs ++ [ python3Packages.yt-dlp ];
})).override
  {
    python3Packages = python3Packages.override {
      overrides = final: prev: {
        soundcloud-v2 = prev.soundcloud-v2.overrideAttrs {
          version = "1.6.1";
          src = fetchPypi {
            pname = "soundcloud_v2";
            version = "1.6.1";
            hash = "sha256-tmRueIOpmGqSvftsre2cplRTiZ+QUX5H7PgtIcoK5ic=";
          };
        };
      };
    };
  }
