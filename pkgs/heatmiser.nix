# MIT License
#
# Copyright (c) 2018 Francesco Gazzetta
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
{ lib
, fetchFromGitHub
, buildHomeAssistantComponent
, buildPythonPackage
, fetchPypi
, pytest
, pytest-asyncio
, pytest-runner
, websockets
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

    propagatedBuildInputs = [
    ];

    checkInputs = [
      pytest
      pytest-asyncio
      pytest-runner
    ];

    pythonImportsCheck = [ "async_property" ];

    meta = with lib; {
      homepage = "https://github.com/ryananguiano/async_property";
      description = "Python decorator for async properties";
      license = licenses.mit;
      maintainers = with maintainers; [ graham33 ];
    };
  };

  neohubapi = buildPythonPackage rec {
    pname = "neohubapi";
    version = "1.0";

    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-lmz9jgdBN+VnZnE/ckNUK9YNINtVj90iCZbCQBL/XXc=";
    };

    propagatedBuildInputs = [
      async-property
      websockets
    ];

    checkInputs = [ ];

    pythonImportsCheck = [ "neohubapi" ];

    meta = with lib; {
      homepage = "https://gitlab.com/neohubapi/neohubapi";
      description = "Async library to communicate with Heatmiser NeoHub 2 API";
      license = licenses.mit;
      maintainers = with maintainers; [ graham33 ];
    };
  };
in
buildHomeAssistantComponent {
  owner = "graham33";
  domain = "heatmiserneo";
  version = "0.0.1-pre0d4905c";
  format = "other";

  src = fetchFromGitHub {
    owner = "MindrustUK";
    repo = "heatmiser-for-home-assistant";
    rev = "0d4905c022fca39c3b8134ece7246e3fabc00a84";
    sha256 = "sha256-nrpAvPyo4OFJcGdZKshaAxXmk6LvyOnJv99XEejXCh4=";
  };

  propagatedBuildInputs = [
    neohubapi
  ];

  meta = with lib; {
    homepage = "https://github.com/MindrustUK/heatmiser-for-home-assistant";
    license = licenses.asl20;
    description = "Heatmiser Neo-Hub / Neostat / Neostat-e support for home-assistant.io";
    maintainers = with maintainers; [ graham33 ];
  };
}
