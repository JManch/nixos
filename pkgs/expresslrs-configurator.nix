{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  makeWrapper,
  udevCheckHook,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  python3,
  nodejs,
  git,
  platformio,
  makeDesktopItem,
}:
let
  electron =
    (import (fetchTree "github:NixOS/nixpkgs/0bd7f95e4588643f2c2d403b38d8a2fe44b0fc73") {
      inherit (stdenv.hostPlatform) system;
    }).electron_27.overrideAttrs
      (old: {
        meta = lib.removeAttrs old.meta [ "knownVulnerabilities" ];
      });

  udevRules = fetchurl {
    url = "https://raw.githubusercontent.com/platformio/platformio-core/refs/heads/develop/platformio/assets/system/99-platformio-udev.rules";
    hash = "sha256-CfOs4g5GoNXeRUmkKY7Kw9KdgOqX5iRLMvmP+u3mqx8=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "expresslrs-configurator";
  version = "1.7.11";

  src = fetchFromGitHub {
    owner = "ExpressLRS";
    repo = "ExpressLRS-Configurator";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Z7dH7kA27Q0uEUp5QK2bYpF5nj0hwXQrdwRCriZypkU=";
  };

  postPatch = ''
    # https://github.com/electron/electron/issues/31121
    substituteInPlace src/main/main.ts \
      --replace-fail "process.resourcesPath" "'$out/share/expresslrs-configurator/resources'"
  '';

  yarnOfflineCacheRoot = fetchYarnDeps {
    yarnLock = finalAttrs.src + "/yarn.lock";
    hash = "sha256-aMKPWtT8rc1pM0FlmZjRsc95l3OIA9b+P1fL3QYiZa4=";
  };

  yarnOfflineCacheApp = fetchYarnDeps {
    yarnLock = finalAttrs.src + "/release/app/yarn.lock";
    hash = "sha256-OYLWJH7/AskiZJnLsUdBOIK59XGzobdUsj+Wf5wZ/Zc=";
  };

  dontYarnInstallDeps = true;

  preConfigure = ''
    # use electron's headers to make node-gyp compile against the electron ABI
    export npm_config_nodedir=$(mktemp -d)
    # I'm not sure why headers are packaged in a tarball in old nixpkgs...
    # if I expresslrs ever gets an electron update this will need to change
    tar -xf "${electron.headers}" --strip-components=1 -C "$npm_config_nodedir"
  '';

  postConfigure = ''
    yarnOfflineCache="$yarnOfflineCacheRoot" yarnConfigHook
    pushd release/app
    yarnOfflineCache="$yarnOfflineCacheApp" yarnConfigHook
    popd
  '';

  strictDeps = true;
  nativeBuildInputs = [
    makeWrapper
    yarnConfigHook
    yarnBuildHook

    nodejs
    python3
  ];

  yarnBuildScript = "package";

  yarnBuildFlags = [
    "--dir"
    "-c.electronDist=${electron.dist}"
    "-c.electronVersion=${electron.version}"
  ];

  nativeInstallCheckInputs = [ udevCheckHook ];
  doInstallCheck = true;

  desktopItem = makeDesktopItem {
    name = finalAttrs.pname;
    desktopName = "ExpressLRS Configurator";
    type = "Application";
    exec = finalAttrs.pname;
    icon = finalAttrs.src + "/assets/icon.png";
  };

  installPhase = ''
    mkdir -p $out/bin $out/share/expresslrs-configurator
    cp -r release/linux-unpacked/{resources,dependencies} $out/share/expresslrs-configurator

    makeWrapper ${lib.getExe electron} $out/bin/expresslrs-configurator \
      --add-flag "$out/share/expresslrs-configurator/resources/app.asar" \
      --add-flag "--disable-gpu" \
      --prefix PATH : "${
        lib.makeBinPath [
          git
          python3
          platformio
        ]
      }"

      # Has issues closing with wayland
      # --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \

    install -m444 -D ${udevRules} -t $out/lib/udev/rules.d
    install -m444 -D $desktopItem/share/applications/*.desktop -t $out/share/applications
  '';

  meta = {
    description = "Cross platform configuration & build tool for the ExpressLRS radio link";
    homepage = "https://github.com/ExpressLRS/ExpressLRS-Configurator";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ JManch ];
    mainProgram = "expresslrs-configurator";
    platforms = electron.meta.platforms;
  };
})
