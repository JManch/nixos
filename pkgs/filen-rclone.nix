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

  vendorHash = "sha256-GVbec1V8hejhNekCPJ808i23qkDZOvNI4xneEFVZKTI=";
  dontVersionCheck = true;
})
