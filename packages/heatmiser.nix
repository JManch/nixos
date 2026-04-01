{ home-assistant, sources }:
home-assistant.python.pkgs.callPackage (
  # MIT License
  #
  # Copyright (c) 2018 Francesco Gazzetta, Joshua Manchester
  #
  # Permission is hereby granted, free of charge, to any person obtaining a copy
  # of this software and associated documentation files (the "Software"), to deal
  # in the Software without restriction, including without limitation the rights
  # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  # copies of the Software, and to permit persons to whom the Software is
  # furnished to do so, subject to the following conditions:
  #
  # The above copyright notice and this permission notice shall be included in all
  # copies or substantial portions of the Software.
  #
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  # SOFTWARE.
  {
    buildHomeAssistantComponent,
    buildPythonPackage,
    websockets,
    setuptools,
    ...
  }:
  let
    async-property = buildPythonPackage {
      pname = "async-property";
      inherit (sources.async-property) version;
      src = sources.async-property;
      pyproject = true;
      build-system = [ setuptools ];

      postPatch = ''
        substituteInPlace setup.py \
          --replace-fail "'pytest-runner'" ""
      '';

      pythonImportsCheck = [ "async_property" ];
    };

    neohubapi = buildPythonPackage {
      pname = "neohubapi";
      inherit (sources.neohubapi) version;
      src = sources.neohubapi;
      pyproject = true;
      build-system = [ setuptools ];

      propagatedBuildInputs = [
        async-property
        websockets
      ];

      pythonImportsCheck = [ "neohubapi" ];
    };
  in
  buildHomeAssistantComponent {
    owner = "MindrustUK";
    domain = "heatmiserneo";
    inherit (sources.heatmiser-for-home-assistant) version;
    src = sources.heatmiser-for-home-assistant;
    propagatedBuildInputs = [ neohubapi ];
  }
) { }
