{
  lib,
  pkgs,
  osConfig,
}:
{
  enableOpt = true;

  opts = {
    promptColor = lib.mkOption {
      type = lib.types.str;
      default = "green";
    };
  };

  home.packages =
    (with pkgs; [
      unzip
      zip
      p7zip
      tree
      wget
      fd
      ripgrep
      bat
      tokei
      rename
      nurl # tool for generating nix fetcher calls from urls
      file
      jaq
      man-pages
      rsync
      sd
    ])
    ++ lib.optional (osConfig != null) pkgs.microfetch;

  home.sessionVariables.COLORTERM = "truecolor";
}
