{ ns, ... }:
{
  ${ns} = {
    core.standalone = true;

    shell = {
      enable = true;
      promptColor = "green";
    };

    programs = {
      git.enable = true;
      neovim.enable = true;
      btop.enable = true;
      fastfetch.enable = true;
    };
  };

  home.stateVersion = "24.05";
}
