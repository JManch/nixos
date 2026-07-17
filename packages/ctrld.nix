{
  lib,
  buildGoModule,
  sources,
}:
buildGoModule {
  pname = "ctrld";
  inherit (sources.ctrld) version;
  src = sources.ctrld;

  vendorHash = "sha256-bWF7XSaMx1/7OEfBjZ+dr7qRT2UlZSaHGqmPO7i2EQA=";

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
