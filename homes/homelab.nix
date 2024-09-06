{ ns, ... }:
{
  ${ns} = {
    shell = {
      enable = true;
      promptColor = "blue";
    };

    programs = {
      btop.enable = true;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };
  };

  home.stateVersion = "24.05";
}
