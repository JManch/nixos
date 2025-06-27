{
  stdenvNoCC,
  scdoc,
  sources,
  installShellFiles,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "xdg-terminal-exec";
  inherit (sources.xdg-terminal-exec) version;
  src = sources.xdg-terminal-exec;

  nativeBuildInputs = [
    scdoc
    installShellFiles
  ];

  installPhase = ''
    installBin xdg-terminal-exec
    installManPage xdg-terminal-exec.1.gz
    install -Dm644 xdg-terminals.list -t $out/share/xdg-terminal-exec
  '';

  meta.mainProgram = "xdg-terminal-exec";
})
