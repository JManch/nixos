{
  buildDotnetModule,
  dotnetCorePackages,
  sources,
  ...
}:
buildDotnetModule (finalAttrs: {
  pname = "jellyfin-plugin-listenbrainz";
  inherit (sources.jellyfin-plugin-listenbrainz) version;
  src = sources.jellyfin-plugin-listenbrainz;

  nugetDeps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  enableParallelBuilding = false; # build randomly fails otherwise

  installPhase = ''
    install -Dm444 src/Jellyfin.Plugin.ListenBrainz/bin/Release/net8.0/Jellyfin.Plugin.ListenBrainz*.dll -t $out/ListenBrainz_${finalAttrs.version}
  '';
})
