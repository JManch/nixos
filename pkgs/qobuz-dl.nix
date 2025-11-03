{
  buildPythonApplication,
  setuptools,
  beautifulsoup4,
  colorama,
  mutagen,
  pathvalidate,
  pick,
  requests,
  tqdm,
  sources,
  fetchFromGitHub,
  ...
}:
let
  pick_1_6_0 = pick.overrideAttrs {
    version = "1.6.0";
    src = fetchFromGitHub {
      owner = "wong2";
      repo = "pick";
      tag = "v1.6.0";
      hash = "sha256-aFTLvMNWcfblALCgCtaec0e//rN2n4nGUt5YkfmLjm0=";
    };
  };
in
buildPythonApplication {
  pname = "qobuz-dl";
  inherit (sources.qobuz-dl) version;
  src = sources.qobuz-dl;

  pyproject = true;

  build-system = [ setuptools ];

  dependencies = [
    pathvalidate
    requests
    mutagen
    tqdm
    pick_1_6_0
    beautifulsoup4
    colorama
  ];

  pythonImportsCheck = [ "qobuz_dl" ];

  meta.mainProgram = "qobuz-dl";
}
