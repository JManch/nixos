{ pkgs }:
{
  home.packages = with pkgs; [
    picard
    spek
  ];
}
