{
  lib,
  home-assistant,
  sources,
}:
home-assistant.python3Packages.callPackage (
  {
    buildHomeAssistantComponent,
    highspy,
    numpy,
    fetchPypi,
    ...
  }:
  buildHomeAssistantComponent {
    owner = "hass-energy";
    domain = "haeo";
    inherit (sources.haeo) version;
    src = sources.haeo;

    dependencies = [
      (highspy.overridePythonAttrs {
        version = "1.15.1";
        src = fetchPypi {
          pname = "highspy";
          version = "1.15.1";
          hash = "sha256-IO0vvxy2S/METuZjI2S34mU9k+aQHisZ/T1d8QcC6MU=";
        };
      })
      numpy
    ];

    meta = {
      description = "Home Assistant energy optimiser";
      homepage = "https://github.com/hass-energy/haeo";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ JManch ];
    };
  }
) { }
