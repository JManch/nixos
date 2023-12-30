{ inputs
, pkgs
, ...
}: {
  imports = [
    inputs.agenix.nixosModules.default
  ];

  environment.systemPackages = [
    inputs.agenix.packages.${pkgs.system}.default
  ];

  age.secrets.joshuaPasswd.file = ../../../secrets/joshuaPasswd.age;
}
