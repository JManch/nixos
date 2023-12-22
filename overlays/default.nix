{ inputs, ... }:
{
  modifications = final: prev: {
    eza = prev.mu.overrideAttrs (_: rec {
      version = 0.10.7;
      src = fetchFromGithub {
        owner = "eza-community";
        repo = "eza";
        rev = "v${version}";
        hash = lib.fakeHash;
      };
    });
  };
}
