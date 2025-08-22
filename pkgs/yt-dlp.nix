# yt-dlp gets frequently updated and often breaks if not up-to-date
{
  yt-dlp,
  sources,
  ...
}:
yt-dlp.overrideAttrs (
  final: _: {
    inherit (sources.yt-dlp) version;
    src = sources.yt-dlp;
  }
)
