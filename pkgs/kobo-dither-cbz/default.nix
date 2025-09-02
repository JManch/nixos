{
  zip,
  unzip,
  findutils,
  imagemagick,
  parallel,
  writeShellApplication,
}:
writeShellApplication {
  name = "kobo-dither-cbz";

  runtimeInputs = [
    zip
    unzip
    imagemagick
    parallel
    findutils
  ];

  text = ''
    echo "Assuming images are already resized so use this script AFTER processing with KCC"

    if [[ $# -eq 0 ]]; then
      echo "Usage: $0 input.cbz"
      exit 1
    fi

    process_cbz() {
      input_cbz=$(realpath "$1")
      basename=$(basename "$input_cbz" .cbz)
      workdir=$(mktemp -d)
      output_cbz="$(dirname "$input_cbz")/''${basename}_dithered.cbz"

      echo "Processing $input_cbz"

      unzip -q "$input_cbz" -d "$workdir"

      find "$workdir" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | while read -r file; do
        magick "$file" \
          -colorspace Lab \
          -filter LanczosSharp \
          -colorspace sRGB \
          -gravity center \
          -grayscale Rec709Luminance \
          -colorspace sRGB \
          -dither FloydSteinberg \
          -remap "${./eink_cmap.gif}" \
          -quality 75 \
          "$file"
      done

      (cd "$workdir" && zip -qr "$output_cbz" ./*)
      rm -rf "$workdir"

      echo "Processed CBZ created: $output_cbz"
    }

    export -f process_cbz
    parallel --will-cite -j 4 process_cbz ::: "$@"
  '';
}
