{
  buildPythonApplication,
  installShellFiles,
  sources,
  beautifulsoup4,
  cloudscraper,
  lxml,
  pillow,
  pypdf,
  requests,
  ...
}:
buildPythonApplication {
  pname = "comick-downloader";
  version = "0-unstable-${sources.comick_downloader.revision}";
  src = sources.comick_downloader;
  pyproject = false;

  dependencies = [
    beautifulsoup4
    cloudscraper
    lxml
    pillow
    pypdf
    requests
  ];

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    mv comick_downloader.py comick_downloader
    installBin comick_downloader
  '';

  meta.mainProgram = "comick_downloader";
}
