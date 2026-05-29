{
  home-assistant,
  sources,
}:
home-assistant.python.pkgs.callPackage (
  {
    buildHomeAssistantComponent,
    bleak,
    bleak-retry-connector,
    ...
  }:
  buildHomeAssistantComponent {
    owner = "pink88";
    domain = "tuiss2ha";
    version = "0-unstable-${sources.tuiss2ha.revision}";
    src = sources.tuiss2ha;

    dependencies = [
      bleak
      bleak-retry-connector
    ];

    meta = {
      description = "Integrates Tuiss Smartview BLE blinds with Home Assistant";
      homepage = "https://github.com/pink88/Tuiss2HA";
    };
  }
) { }
