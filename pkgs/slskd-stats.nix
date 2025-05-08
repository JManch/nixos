{
  buildPythonApplication,
  sources,
}:
buildPythonApplication {
  pname = "slskd-stats";
  inherit (sources.slskd-stats) version;
  src = sources.slskd-stats;
  pyproject = false;

  installPhase = ''
    install -Dm755 main.py $out/bin/slskd-stats
  '';

  meta.mainProgram = "slskd-stats";
}
