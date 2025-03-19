{
  buildPythonPackage,
  setuptools,
  pydantic,
  sources,
  ...
}:
buildPythonPackage {
  pname = "hyprpy";
  inherit (sources.hyprpy) version;
  src = sources.hyprpy;

  patches = [ ../patches/hyprpy-always-on-top.patch ];

  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [ pydantic ];
}
