{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
buildHomeAssistantComponent rec {
  owner = "jwillemsen";
  domain = "daikin_onecta";
  version = "4.1.13";

  src = fetchFromGitHub {
    owner = "jwillemsen";
    repo = "daikin_onecta";
    rev = "refs/tags/v${version}";
    hash = "sha256-Ac0Dgt8Cpevqf42pm/WIeBjrx7M6GZSY4XkCFojm1oA=";
  };

  meta = {
    description = "Home Assistant Integration for devices supported by the Daikin Onecta App";
    homepage = "https://github.com/jwillemsen/daikin_onecta";
    license = lib.licenses.mit;
  };
}
