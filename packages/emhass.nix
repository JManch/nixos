{
  lib,
  python312Packages,
  sources,
}:
let
  skforecast =
    {
      setuptools,
      buildPythonPackage,
      numpy,
      pandas,
      tqdm,
      scikit-learn,
      scipy,
      optuna,
      joblib,
      numba,
      rich,
      toml,
      ...
    }:
    buildPythonPackage {
      pname = "skforecast";
      inherit (sources.skforecast) version;
      src = sources.skforecast;

      pyproject = true;
      build-system = [ setuptools ];
      dependencies = [
        numpy
        pandas
        tqdm
        scikit-learn
        scipy
        optuna
        joblib
        numba
        rich
        toml
      ];
    };
in
python312Packages.callPackage (
  {
    buildPythonApplication,
    setuptools,
    numpy,
    scipy,
    pandas,
    pvlib,
    protobuf,
    pytz,
    h5py,
    highspy,
    cvxpy,
    pyyaml,
    tables,
    waitress,
    plotly,
    gunicorn,
    quart,
    aiofiles,
    jinja2,
    aiohttp,
    orjson,
    websockets,
    uvicorn,
    influxdb,
    fetchPypi,
    hatchling,
    ...
  }:
  buildPythonApplication {
    pname = "emhass";
    inherit (sources.emhass) version;
    src = sources.emhass;

    pyproject = true;
    build-system = [
      setuptools
      hatchling
    ];

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "cvxpy>=1.6.0, <1.8.0" "cvxpy" \
        --replace-fail "numpy>=2.0.0, <2.3.0" "numpy" \
        --replace-fail "uvicorn==0.30.6" "uvicorn" \
        --replace-fail '"asyncio",' ""
    '';

    dependencies = [
      (python312Packages.callPackage skforecast { })
      numpy
      scipy
      pandas
      # pvlib
      (
        assert lib.assertMsg (pvlib.version == "0.14.0") "Remove pvlib override";
        pvlib.overridePythonAttrs {
          version = "0.15.1";
          src = fetchPypi {
            pname = "pvlib";
            version = "0.15.1";
            hash = "sha256-uIJKoo/UtwF5sxiI/EvJycF+HJn/Fxo/7F7cU/k0e80=";
          };
        }
      )
      protobuf
      pytz
      h5py
      highspy
      cvxpy
      pyyaml
      tables
      waitress
      plotly
      gunicorn
      quart
      aiofiles
      jinja2
      aiohttp
      orjson
      websockets
      uvicorn
      influxdb
    ];

    meta = {
      homepage = "https://github.com/davidusb-geek/emhass";
      description = "A Python module designed to optimize your home energy interfacing with Home Assistant";
      maintainers = with lib.maintainers; [ JManch ];
      platforms = lib.platforms.linux;
      mainProgram = "emhass";
    };
  }
) { }
