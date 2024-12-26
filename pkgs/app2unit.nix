{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "app2unit";
  version = "0-unstable-2024-12-26";

  src = fetchFromGitHub {
    owner = "Vladimir-csp";
    repo = "app2unit";
    rev = "e7e325ec701662788e50b7ac8934a7a23e86496b";
    hash = "sha256-5tvGktkdmB3sdnw2wg6vtbC1kMjdRk11Q8a7QbPQMhk=";
  };

  installPhase = "install -Dm755 app2unit -t $out/bin";
}
