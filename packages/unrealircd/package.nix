{
  lib,
  stdenv,
  fetchurl,
  openssl,
  symlinkJoin,
  logDir ? "/var/lib/unrealircd/log",
  tmpDir ? "/var/lib/unrealircd/tmp",
  cacheDir ? "/var/lib/unrealircd/cache",
  dataDir ? "/var/lib/unrealircd/data",
  confDir ? "/var/lib/unrealircd/conf",
}:
let
  opensslCombined = symlinkJoin {
    name = "openssl-combined";
    paths = [
      openssl
      openssl.dev
    ];
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "unrealircd";
  version = "6.2.2";

  src = fetchurl {
    url = "https://www.unrealircd.org/downloads/unrealircd-${finalAttrs.version}.tar.gz";
    hash = "sha256-AcVHZzQSFppWWYcmYtRgkrHRahuo/GCk9fatFE+Hhvg=";
  };

  patches = [
    ./no-set-tmpdir.patch
    ./no-runtime-dir-creation.patch
    ./no-source-symlink.patch
  ];

  OPENSSLPATH = opensslCombined;

  strictDeps = true;

  buildInputs = [ openssl ];

  configureFlags = [
    "--enable-ssl=${opensslCombined}"
    "--with-bindir=${placeholder "out"}/bin"
    "--with-datadir=${dataDir}"
    "--with-pidfile=${tmpDir}/unrealircd.pid"
    "--with-controlfile=${tmpDir}/unrealircd.ctl"
    "--with-confdir=${confDir}"
    "--with-modulesdir=${placeholder "out"}/modules"
    "--with-docdir=${placeholder "out"}/share/doc"
    "--with-logdir=${logDir}"
    "--with-cachedir=${cacheDir}"
    "--with-tmpdir=${tmpDir}"
    "--with-privatelibdir=${placeholder "out"}/lib"
    "--with-scriptdir=/tmp" # we dont care about the start/stop script
    "--with-nick-history=2000"
    "--with-permissions=0600"
    "--enable-dynamic-linking"
    "--enable-geoip-classic"
  ];

  configurePhase = ''
    echo "Skipping configure phase"
  '';

  # Since their configure script actually builds the program probably makes
  # more sense to do in this phase
  buildPhase = ''
    ./configure $configureFlags
  '';

  meta = {
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ JManch ];
    mainProgram = "unrealircd";
  };
})
