{
  buildPythonPackage,
  fetchPypi,
  setuptools,
  pydantic,
  ...
}:
buildPythonPackage rec {
  pname = "hyprpy";
  version = "0.1.8";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-15FGnc09cQyJWejOLV/+TTcJQKMX4RLPe+exqPFvMc8=";
  };

  format = "pyproject";

  build-system = [ setuptools ];

  dependencies = [ pydantic ];
}
