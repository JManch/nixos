{
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  pydantic,
  ...
}:
buildPythonPackage {
  pname = "hyprpy";
  version = "0.1.8";

  # PR fixes issue with fullscreen state
  src = fetchFromGitHub {
    repo = "hyprpy";
    owner = "Evangelospro";
    rev = "867e7c97670ac9a322af64d5e46dfa46c68805b6";
    hash = "sha256-SPfFl1meI32hafFObyOvTHtcLMJB1SSd7aV29ian+Xc=";
  };

  format = "pyproject";

  build-system = [ setuptools ];

  dependencies = [ pydantic ];
}
