{
  lib,
  edgetx,
  cmake,
  ninja,
  kdePackages,
  udevCheckHook,
  python3,
  SDL2,
  fox_1_6,
  fetchFromGitHub,
  callPackage,
  imgui,
}:
let
  version = "2.12.0-rc4";

  maxlibqt = fetchFromGitHub {
    owner = "edgetx";
    repo = "maxLibQt";
    rev = "7e433da60d3f2e975d46afc91804a88029cd1b78";
    hash = "sha256-1Pl8TVBNLE97XJcP68A0+zVCvBlXt+mPFxjM9YbF8CU=";
  };
in
edgetx.overrideAttrs (old: {
  inherit version;
  src = fetchFromGitHub {
    owner = "EdgeTX";
    repo = "edgetx";
    tag = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-Fike8da7yQgDNUG7HAJWB3/RFxfT/EPb8Ud8q3RMMqA=";
  };

  patches = old.patches ++ [ ./install-desktop-files.patch ];

  postPatch = ''
    sed -i "/include(FetchRsDfu)/d" cmake/NativeTargets.cmake
    sed -i "/include(FetchImgui)/d" radio/src/targets/simu/CMakeLists.txt
    patchShebangs companion/util radio/util
  '';

  cmakeFlags =
    (lib.filter (
      x: !lib.hasInfix "FETCHCONTENT_SOURCE_DIR_MAXLIBQT" x && !lib.hasInfix "DFU_UTIL_ROOT_DIR" x
    ) old.cmakeFlags)
    ++ [
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_MAXLIBQT" "${maxlibqt}")
      (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    ];

  nativeBuildInputs =
    let
      pythonEnv = python3.withPackages (
        pyPkgs: with pyPkgs; [
          pillow
          lz4
          jinja2
          libclang
        ]
      );
    in
    [
      cmake
      ninja
      pythonEnv
      kdePackages.wrapQtAppsHook
      kdePackages.qttools
      udevCheckHook
    ];

  buildInputs = [
    kdePackages.qtbase
    kdePackages.qtmultimedia
    kdePackages.qtserialport
    SDL2
    fox_1_6
    (callPackage ./rs-dfu.nix { })
    imgui
  ];
})
