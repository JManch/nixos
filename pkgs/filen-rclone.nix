{
  sources,
  rclone,
}:
rclone.overrideAttrs (old: {
  pname = "filen-rclone";
  version = "0-unstable-${sources.filen-rclone.revision}";
  src = sources.filen-rclone;
  patches = [ ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/rclone/rclone/fs.Version=${sources.filen-rclone.revision}"
  ];

  vendorHash = "sha256-JXavjdcDE6L+6db5zQtIiS0KxY6wtaZyyvuN+UmCU+A=";
  dontVersionCheck = true;
})
