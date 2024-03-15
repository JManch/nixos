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
, python312
}:
buildHomeAssistantComponent rec {
  owner = "graham33";
  domain = "frigate";
  version = "5.0.1";
  format = "other";

  src = fetchFromGitHub {
    owner = "blakeblackshear";
    repo = "frigate-hass-integration";
    rev = "v${version}";
    sha256 = "sha256-XJmekSsY9hAs8Scc5PMqiviMwNerKXNiYb+7wwPXFpQ=";
  };

  postPatch = ''
    substituteInPlace custom_components/frigate/manifest.json \
      --replace 'pytz==2022.7' 'pytz>=2022.7'
  '';

  propagatedBuildInputs = with python312.pkgs; [
    pytz
  ];

  # TODO: default installPhase uses $src, so patches don't take effect
  installPhase = ''
    runHook preInstall
    mkdir $out
    cp -r custom_components/ $out/
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/blakeblackshear/frigate-hass-integration";
    license = licenses.mit;
    description = "Frigate Home Assistant integration";
  };
}
