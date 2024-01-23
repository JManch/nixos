{ lib
, bash
, coreutils
, libnotify
, stdenvNoCC
, makeWrapper
, fetchFromGitHub
}:
stdenvNoCC.mkDerivation {
  pname = "pomo";
  version = "2023-03-15";

  src = fetchFromGitHub {
    repo = "pomo";
    owner = "jsspencer";
    rev = "5a1e3f9c2291bb1ce3bdd6c18ecc1a063b0f6655";
    sha256 = "";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 pomo.sh -t "$out/bin/pomo"
    wrapProgram "$out/bin/pomo" \
      --prefix PATH ":" ${lib.makeBinPath [
        bash coreutils libnotify
      ]}

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/jsspencer/pomo";
    description = "A simple Pomodoro timer written in bash.";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
    mainProgram = "pomo";
    platforms = platforms.linux;
  };
}
