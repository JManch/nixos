{
  python3Packages,
  sources,
}:
python3Packages.buildPythonPackage {
  pname = "hyprpy";
  inherit (sources.hyprpy) version;
  src = sources.hyprpy;

  patches = [ ../patches/hyprpy-always-on-top.patch ];

  pyproject = true;
  build-system = [ python3Packages.setuptools ];
  dependencies = [ python3Packages.pydantic ];
}
