{
  lib,
  home-assistant,
  sources,
}:
home-assistant.python3Packages.callPackage (
  {
    buildHomeAssistantComponent,
    aiohttp,
    aiofiles,
    watchdog,
    watchfiles,
    ...
  }:
  buildHomeAssistantComponent {
    owner = "BJReplay";
    domain = "solcast_solar";
    inherit (sources.solcast-solar) version;
    src = sources.solcast-solar;

    dependencies = [
      aiohttp
      aiofiles
      watchdog
      watchfiles
    ];

    meta = {
      description = "Solcast Integration for Home Assistant";
      homepage = "https://github.com/BJReplay/ha-solcast-solar";
      maintainers = with lib.maintainers; [ JManch ];
    };
  }
) { }
