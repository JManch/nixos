{
  lib,
  buildGoModule,
  sources,
}:
buildGoModule {
  pname = "ctrld";
  inherit (sources.ctrld) version;
  src = sources.ctrld;

  vendorHash = "sha256-FgZGmGxSfmd5SwyAvrVmuJ+Okh8qDppg2gLxJzi9db0=";

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${sources.ctrld.version}"
    "-X=main.commit=${sources.ctrld.revision}"
  ];

  doCheck = false;

  meta = {
    description = "A highly configurable, multi-protocol DNS forwarding proxy";
    homepage = "https://github.com/Control-D-Inc/ctrld";
    license = lib.licenses.mit;
    mainProgram = "ctrld";
  };
}
