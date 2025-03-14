{
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  pydantic,
  ...
}:
buildPythonPackage rec {
  pname = "hyprpy";
  version = "0.1.9";

  src = fetchFromGitHub {
    repo = "hyprpy";
    owner = "ulinja";
    tag = "v${version}";
    hash = "sha256-xnvoiHxDxYVwR1ZrKRGWB5oManaJSP/2sDsQ7KLRpmE=";
  };

  patches = [ ../patches/hyprpyAlwaysOnTop.patch ];

  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [ pydantic ];
}
