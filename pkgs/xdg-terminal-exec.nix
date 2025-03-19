{
  stdenvNoCC,
  scdoc,
  sources,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "xdg-terminal-exec";
  inherit (sources.xdg-terminal-exec) version;
  src = sources.xdg-terminal-exec;

  nativeBuildInputs = [ scdoc ];

  installPhase = ''
    install -Dm755 xdg-terminal-exec -t $out/bin
    install -Dm644 xdg-terminal-exec.1.gz -t $out/share/man/man1
    install -Dm644 xdg-terminals.list -t $out/share/xdg-terminal-exec
  '';

  meta.mainProgram = "xdg-terminal-exec";
})
