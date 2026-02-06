{
  lib,
  fetchurl,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "luck-perms";
  version = "5.5.32";

  src = fetchurl {
    url = "https://download.luckperms.net/1620/bukkit/loader/LuckPerms-Bukkit-${finalAttrs.version}.jar";
    hash = "sha256-0AkeHZlcRtKDz9IBZ4GhlRjLm7VqNj2QIEaXDSvwf/c=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m444 -D $src -t $out
  '';

  meta = with lib; {
    homepage = "https://luckperms.net/";
    description = "Permissions plugin for Minecraft servers";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
  };
})
