{
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
}:
buildDotnetModule (finalAttrs: {
  pname = "jellyfin-plugin-listenbrainz";
  version = "5.0.2.0";

  src = fetchFromGitHub {
    owner = "lyarenei";
    repo = "jellyfin-plugin-listenbrainz";
    rev = "refs/tags/${finalAttrs.version}";
    hash = "sha256-r6oKrFac/g0Nc7wc66LvIJVXKBvGa8UMILiXFMi2VXg=";
  };

  nugetDeps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  enableParallelBuilding = false; # build randomly fails otherwise

  installPhase = ''
    install -Dm444 src/Jellyfin.Plugin.ListenBrainz/bin/Release/net8.0/Jellyfin.Plugin.ListenBrainz*.dll -t $out/ListenBrainz_${finalAttrs.version}
  '';
})
