{
  lib,
  buildGoModule,
  sources,
  fetchFromGitHub,
}:
buildGoModule {
  pname = "ctrld";
  # inherit (sources.ctrld) version;
  version = "v1.4.9";
  src =
    # When removing this consider switching to v2.0.0 assuming the branch is up to date
    assert lib.assertMsg (sources.ctrld.version == "v1.4.8") "Remove the ctrld override";
    fetchFromGitHub {
      owner = "Control-D-Inc";
      repo = "ctrld";
      rev = "3beffd0dc8701a0d3eba4030dbcb27fe919b0360";
      hash = "sha256-FYlsnBuYgLXw2d2ppuHuDsricKYKPZ2IlSD3HjEpI/Y=";
    };

  vendorHash = "sha256-Wydxn7tRFU3SXdY3NIlI+Welwxs1UcNHzYz5AwDI/L8=";

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
