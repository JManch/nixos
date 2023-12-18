{ pkgs, ... }: {
  # TODO: Change this to false once I've got encrypted secrets setup
  users.mutableUsers = true;
  users.users = {
    joshua = {
      isNormalUser = true;
      # TODO: Setup ssh keys
      openssh.authorizedKeys.keys = [ ];
      shell = pkgs.zsh;
      extraGroups = ["wheel"];
    };
  };
}
