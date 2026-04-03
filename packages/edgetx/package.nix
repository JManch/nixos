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
  version = "2.12.0";

  maxlibqt = fetchFromGitHub {
    owner = "edgetx";
    repo = "maxLibQt";
    rev = "7e433da60d3f2e975d46afc91804a88029cd1b78";
    hash = "sha256-1Pl8TVBNLE97XJcP68A0+zVCvBlXt+mPFxjM9YbF8CU=";
  };
in
(edgetx.override {
  targetsToBuild = [
    "x9lite"
    "x9lites"
    "x9d"
    "x9dp"
    "x9dp2019"
    "x9e"
    "x7"
    "x7access"
    "t8"
    "t12"
    "t12max"
    "tx12"
    "tx12mk2"
    "t15"
    "t15pro"
    "t16"
    "t18"
    "t20"
    "t20v2"
    "xlite"
    "xlites"
    "x10"
    "x10express"
    "x12s"
    "zorro"
    "tx16s"
    "tx16smk3"
    "tx15"
    "commando8"
    "boxer"
    "pocket"
    "mt12"
    "gx12"
    "tlite"
    "tpro"
    "tprov2"
    "tpros"
    "bumblebee"
    "lr3pro"
    "t14"
    "nv14"
    "el18"
    "pl18"
    "pl18ev"
    "pl18u"
    "st16"
    "pa01"
    "f16"
    "v14"
    "v16"
  ];
}).overrideAttrs
  (old: {
    inherit version;
    src = fetchFromGitHub {
      owner = "EdgeTX";
      repo = "edgetx";
      tag = "v${version}";
      fetchSubmodules = true;
      hash = "sha256-bwS0nD1beXgqG1uiRZOK2rbhwAFvX/3nHAWPsuh7HWM=";
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
