{
  lib,
  fetchurl,
  fetchFromGitHub,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "levelled-mobs";
  version = "4.5.1";

  src = fetchurl {
    url = "https://github.com/ArcanePlugins/LevelledMobs/releases/download/v4.5.1/LevelledMobs-4.5.1.b143.jar";
    hash = "sha256-6LWNwtTksBNTK6nGs1BykC1hVprMxPb6Hh5PwdNlqcE=";
  };

  srcRepo = fetchFromGitHub {
    owner = "ArcanePlugins";
    repo = "LevelledMobs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8uZx/RVUhnql/tOxyS2kn36NgjmtFQJEgaq1Z3XfI1o=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m444 -D $src -t $out
    install -m444 -D $srcRepo/levelledmobs-plugin/src/main/resources/* -t $out/config
  '';

  meta = with lib; {
    homepage = "https://github.com/ArcanePlugins/LevelledMobs";
    description = "Level-up mobs on your Spigot/Paper server";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
})
