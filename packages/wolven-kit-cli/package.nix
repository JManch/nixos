{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  sources,
}:
buildDotnetModule {
  name = "wolven-kit-cli";
  inherit (sources.Wolvenkit) version;
  src = sources.Wolvenkit;

  projectFile = "WolvenKit.CLI/WolvenKit.CLI.csproj";
  nugetDeps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_8_0;

  meta = {
    homepage = "https://github.com/WolvenKit/WolvenKit";
    license = lib.licenses.agpl3Only;
    mainProgram = "WolvenKit.CLI";
  };
}
