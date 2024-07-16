{
  lib,
  fetchurl,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "aura-skills";
  version = "2.0.9";

  src = fetchurl {
    url = "https://github.com/Archy-X/AuraSkills/releases/download/${version}/AuraSkills-${version}.jar";
    sha256 = "sha256-XZrt2pyoyNXyc5KEOBCG0gwZyjLfnmlk2CpM6QvZCxk=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m555 -D ${src} -t "$out"
  '';

  meta = with lib; {
    homepage = "https://github.com/Archy-X/AuraSkills";
    description = "The ultra-versatile RPG skills plugin";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
}
