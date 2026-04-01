{
  lib,
  fetchurl,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "vivecraft";
  version = "1.3.5-0";

  src = fetchurl {
    url = "https://github.com/Vivecraft/Vivecraft-Spigot-Extension/releases/download/${finalAttrs.version}/Vivecraft-Spigot-Extension-${finalAttrs.version}.jar";
    hash = "sha256-f8UA6H3q9a6qT1rL7fpaF4hVFzM4p9N2UcBUXyENhfw=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    install -m444 -D $src -t $out
  '';

  meta = with lib; {
    homepage = "https://github.com/jrbudda/Vivecraft_Spigot_Extensions";
    description = "Spigot plugin for Vivecraft, the VR mod for Java Minecraft.";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
})
