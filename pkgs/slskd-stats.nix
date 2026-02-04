{
  python3Packages,
  sources,
  installShellFiles,
}:
python3Packages.buildPythonApplication {
  pname = "slskd-stats";
  inherit (sources.slskd-stats) version;
  src = sources.slskd-stats;
  pyproject = false;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    mv main.py slskd-stats
    installBin slskd-stats
  '';

  meta.mainProgram = "slskd-stats";
}
