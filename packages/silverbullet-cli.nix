{
  JManch,
  buildGoModule,
}:
buildGoModule (finalAttrs: {
  pname = "silverbullet-cli";
  inherit (JManch.silverbullet) version src vendorHash;
  subPackages = [ "./cmd/cli" ];
  doCheck = false;
  ldflags = [
    "-X main.version=${finalAttrs.version}"
  ];
  meta.mainProgram = "cli";
})
