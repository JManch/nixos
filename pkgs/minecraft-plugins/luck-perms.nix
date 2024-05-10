{ lib
, fetchurl
, stdenvNoCC
, ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "luck-perms";
  version = "5.4.128";

  src = fetchurl {
    url = "https://download.luckperms.net/1541/bukkit/loader/LuckPerms-Bukkit-${version}.jar";
    sha256 = "sha256-ZALbcMwsAzlq1pR1hwsY9akGWgWRao74t8FAbiDwd0A=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m555 -D ${src} -t "$out"
  '';

  meta = with lib; {
    homepage = "https://luckperms.net/";
    description = "Permissions plugin for Minecraft servers";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
  };
}
