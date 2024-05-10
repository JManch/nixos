{ lib
, fetchzip
, stdenvNoCC
, ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "vivecraft";
  version = "120r1";

  src = fetchzip {
    url = "https://github.com/jrbudda/Vivecraft_Spigot_Extensions/releases/download/${version}/Vivecraft_Spigot_Extensions.1.20.4r1.zip ";
    sha256 = "sha256-4TS6oG7/BegYC/9yvsoYk8eYRmXDA3k8b9KJa3b4VJ4=";
  };

  dontBuild = true;

  installPhase = ''
    install -m555 -D Vivecraft_Spigot_Extensions.jar -t "$out"
  '';

  meta = with lib; {
    homepage = "https://github.com/jrbudda/Vivecraft_Spigot_Extensions";
    description = "Spigot plugin for Vivecraft, the VR mod for Java Minecraft.";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
}
