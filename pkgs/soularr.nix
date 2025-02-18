{
  buildPythonApplication,
  fetchFromGitHub,
  setuptools,
  setuptools-git-versioning,
  requests,
  music-tag,
  pyarr,
  ...
}:
let
  slskd-api = buildPythonApplication rec {
    pname = "slskd-api";
    version = "0.1.5";

    src = fetchFromGitHub {
      owner = "bigoulours";
      repo = "slskd-python-api";
      tag = "v${version}";
      hash = "sha256-Kyzbd8y92VFzjIp9xVbhkK9rHA/6KCCJh7kNS/MtixI=";
    };

    pyproject = true;

    build-system = [
      setuptools
      setuptools-git-versioning
    ];

    dependencies = [
      requests
    ];
  };
in
buildPythonApplication {
  pname = "soularr";
  version = "0-unstable-2025-01-23";

  src = fetchFromGitHub {
    owner = "mrusse";
    repo = "soularr";
    rev = "dd199b19f4097955ec9f82d638836838f9b153e2";
    hash = "sha256-8ATVC5nCTTo8ctRm/LepkGp9jJxYo6dLOwI/3UbCGqE=";
  };

  pyproject = false;

  dependencies = [
    music-tag
    pyarr
    slskd-api
  ];

  installPhase = ''
    install -Dm755 soularr.py $out/bin/soularr
  '';

  meta.mainProgram = "soularr";
}
