{
  sources,
  rclone,
}:
rclone.overrideAttrs (old: {
  pname = "filen-rclone";
  version = "0-unstable-${sources.filen-rclone.revision}";
  # Due to finalAttrs pattern changein
  # https://github.com/NixOS/nixpkgs/pull/487704, even though we override
  # ldflags it still complains about missing tag attribute for the old
  # ldflags??
  src = sources.filen-rclone // {
    tag = "";
  };
  patches = [ ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/rclone/rclone/fs.Version=${sources.filen-rclone.revision}"
  ];

  vendorHash = "sha256-GVbec1V8hejhNekCPJ808i23qkDZOvNI4xneEFVZKTI=";
  dontVersionCheck = true;
})
