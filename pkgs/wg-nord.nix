{
  lib,
  openssl,
  pkg-config,
  rustPlatform,
  fetchFromGitHub,
}:
let
  version = "1.0.0";
in
rustPlatform.buildRustPackage {
  pname = "wg-nord";
  inherit version;

  src = fetchFromGitHub {
    owner = "n-thumann";
    repo = "wg-nord";
    rev = "refs/tags/v${version}";
    hash = "sha256-clSRqwsFkjbn6d4S6R6DN/6OkQEAEliU/UmjGxx9Tdo=";
  };

  cargoHash = "sha256-lXAXjuk38H1/DMHc6ZANTdledE3QQOoyrK/XzyVhI64=";

  OPENSSL_NO_VENDOR = 1;
  buildInputs = [ openssl ];
  nativeBuildInputs = [ pkg-config ];

  meta = {
    description = "Command-line tool for generating WireGuard configuration files for NordVPN";
    homepage = "https://github.com/n-thumann/wg-nord";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ JManch ];
    platforms = lib.platforms.linux;
    mainProgram = "wg-nord";
  };
}
