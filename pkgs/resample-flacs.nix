{ sox, writeShellApplication }:
writeShellApplication {
  name = "resample-flacs";
  runtimeInputs = [ sox ];
  text = ''
    # Resamples flacs to 16 bit 44.1khz with minimal quality loss
    if [[ $# -eq 0 ]]; then
      echo "Usage: resample-flacs <directory1> [directory2 ...]" >&2
      exit 1
    fi

    shopt -s nullglob

    for dir in "$@"; do
      if [[ ! -d "$dir" ]]; then
        echo -e "Error: '$dir' is not a directory. Skipping." >&2
        continue
      fi

      (
        echo "Resampling flacs in '$dir'..."

        source="''${dir%/}"
        failed=true
        tmp_dir=$(mktemp -d "resample-flacs-tmp.XXXXXX")

        # shellcheck disable=SC2317,SC2329
        cleanup() {
          rm -rf "$tmp_dir"
          if [[ $failed == true ]]; then
            echo "Resampling in '$dir' failed. Flacs have not been modified." >&2
          fi
        }
        trap cleanup EXIT

        for input_file in "$source"/*.flac; do
          filename=$(basename "$input_file")
          sample_rate=$(soxi -r "$input_file")
          bitrate=$(soxi -b "$input_file")

          if [[ $sample_rate -gt 44100 || $bitrate -gt 16 ]]; then
            sox -G "$input_file" -b 16 --comment "" "$tmp_dir/$filename" rate -v 44100
            echo "Resampled $filename: $bitrate/''${sample_rate}Hz -> 16/44100Hz"
          else
            echo "Skipping $filename: $bitrate/''${sample_rate}Hz"
          fi
        done

        for resampled_file in "$tmp_dir"/*; do
          filename=$(basename "$resampled_file")
          mv "$resampled_file" "$source/$filename"
        done

        failed=false
        echo -e "Successfully resampled and overwrote flacs in '$dir'\n"
      )
    done
  '';
}
