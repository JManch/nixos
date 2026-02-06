{
  lib,
  fetchurl,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "aura-skills";
  version = "2.3.10";

  src = fetchurl {
    url = "https://github.com/Archy-X/AuraSkills/releases/download/${finalAttrs.version}/AuraSkills-${finalAttrs.version}.jar";
    hash = "sha256-MPERm6y9gAokBH84/1Ap5ij5smnThFXSI+fEtsDdxwA=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m555 -D $src -t $out
  '';

  meta = with lib; {
    homepage = "https://github.com/Archy-X/AuraSkills";
    description = "The ultra-versatile RPG skills plugin";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
})
