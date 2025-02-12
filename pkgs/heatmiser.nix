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
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  buildPythonPackage,
  fetchPypi,
  pytest,
  pytest-asyncio,
  websockets,
}:
let
  async-property = buildPythonPackage rec {
    pname = "async-property";
    version = "0.2.2";

    src = fetchFromGitHub {
      owner = "ryananguiano";
      repo = "async_property";
      rev = "v${version}";
      sha256 = "sha256-Bn8PDAGNLeL3/g6mB9lGQm1jblHIOJl2w248McJ3oaE=";
    };

    postPatch = ''
      substituteInPlace setup.py \
        --replace-fail "'pytest-runner'" ""
    '';

    nativeCheckInputs = [
      pytest
      pytest-asyncio
    ];

    pythonImportsCheck = [ "async_property" ];
  };

  neohubapi = buildPythonPackage rec {
    pname = "neohubapi";
    version = "2.5";

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-pXBwAPbEFlp20nqJ408zMakwkyNrRoSTpwnJ5trRNwM=";
    };

    propagatedBuildInputs = [
      async-property
      websockets
    ];

    pythonImportsCheck = [ "neohubapi" ];
  };
in
buildHomeAssistantComponent rec {
  owner = "MindrustUK";
  domain = "heatmiserneo";
  version = "3.1.0-beta.8";

  src = fetchFromGitHub {
    inherit owner;
    repo = "heatmiser-for-home-assistant";
    rev = "refs/tags/v${version}";
    hash = "sha256-nH3UPmXYd44pi5CBf24JMWivoMzUHJfE7DwV83xQt5U=";
  };

  propagatedBuildInputs = [ neohubapi ];
}
