{
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
  dotnetPackages,
}:
buildDotnetModule (finalAttrs: {
  pname = "balatro-mobile-maker";
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "blake502";
    repo = "balatro-mobile-maker";
    tag = "beta-${finalAttrs.version}";
    hash = "sha256-bV3iDpQ+JoNrKCeimxRL24OePeC1wjxk5I7U636IDvQ=";
  };

  buildInputs = [ dotnetPackages.SharpZipLib ];

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  executable = [ "balatro-mobile-maker" ];
  selfContainedBuild = true;
  meta.mainProgram = "balatro-mobile-maker";
})
