{
  lib,
  buildHomeAssistantComponent,
  sources,
  ...
}:
buildHomeAssistantComponent {
  owner = "jwillemsen";
  domain = "daikin_onecta";
  inherit (sources.daikin_onecta) version;
  src = sources.daikin_onecta;

  meta = {
    description = "Home Assistant Integration for devices supported by the Daikin Onecta App";
    homepage = "https://github.com/jwillemsen/daikin_onecta";
    license = lib.licenses.mit;
  };
}
