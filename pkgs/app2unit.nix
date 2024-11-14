{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "app2unit";
  version = "0-unstable-2024-11-02";

  src = fetchFromGitHub {
    owner = "Vladimir-csp";
    repo = "app2unit";
    rev = "6b0f83dcd0a98bec6d69108134f915133eb11e6a";
    hash = "sha256-Op98jvALIg855PZk2L4AaMjkTQ+RVNqi5SuWR8Xe+2c=";
  };

  installPhase = "install -Dm755 app2unit -t $out/bin";
}
