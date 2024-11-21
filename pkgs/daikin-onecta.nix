{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "jwillemsen";
  domain = "daikin_onecta";
  version = "4.1.22";

  src = fetchFromGitHub {
    owner = "jwillemsen";
    repo = "daikin_onecta";
    rev = "refs/tags/v${version}";
    hash = "sha256-g/E655KT6IjJwJCyuGdxmh2Py8x4+q5U1Pu81Yp3Tc8=";
  };

  meta = {
    description = "Home Assistant Integration for devices supported by the Daikin Onecta App";
    homepage = "https://github.com/jwillemsen/daikin_onecta";
    license = lib.licenses.mit;
  };
}
