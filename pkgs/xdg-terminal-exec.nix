{
  stdenvNoCC,
  fetchFromGitHub,
  scdoc,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "xdg-terminal-exec";
  version = "0.12.1";

  src = fetchFromGitHub {
    owner = "Vladimir-csp";
    repo = "xdg-terminal-exec";
    rev = "v${finalAttrs.version}";
    hash = "sha256-9sUm2lqAI04dlYgKl7B/UR3L0pwXeKBB8aBQiE4UcNM=";
  };

  nativeBuildInputs = [ scdoc ];

  installPhase = ''
    install -Dm755 xdg-terminal-exec -t $out/bin
    install -Dm644 xdg-terminal-exec.1.gz -t $out/share/man/man1
    install -Dm644 xdg-terminals.list -t $out/share/xdg-terminal-exec
  '';

  meta.mainProgram = "xdg-terminal-exec";
})
