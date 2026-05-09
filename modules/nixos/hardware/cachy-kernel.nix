# This module just provides a package to use in a host's hardware-configuration.nix
{
  lib,
  pkgs,
  inputs,
}:
{
  enableOpt = false;

  opts.package = lib.mkOption {
    readOnly = true;
    default =
      {
        arch,
        flake ? inputs.nix-cachyos-kernel,
        kernelPackage ? "linux-cachyos-latest",
      }:
      let
        kernel = flake.packages.${pkgs.stdenv.hostPlatform.system}.${kernelPackage}.override {
          lto = "thin"; # basically same performance as full with better build time
          processorOpt = arch;
          cpusched = "bore";
          # no reason to make this lower on laptops according to:
          # https://discourse.ubuntu.com/t/enable-low-latency-features-in-the-generic-ubuntu-kernel-for-24-04/42255
          # https://www.phoronix.com/news/Linux-250Hz-1000Hz-Kernel-2025
          # https://www.phoronix.com/news/Linux-2025-Proposal-1000Hz
          hzTicks = "1000";
          tickrate = "full";
          performanceGovernor = false; # we handle performance scaling with tlp or gamemode
          preemptType = "full";
          ccHarder = true; # extra compiler optimisations
          bbr3 = true; # better tcp congestion control
          hugepage = "always";
        };
      in
      ((pkgs.callPackage "${flake.outPath}/helpers.nix" { }).kernelModuleLLVMOverride (
        pkgs.linuxKernel.packagesFor kernel
      )).extend
        (
          _: _: {
            zfs_cachyos = flake.packages.${pkgs.stdenv.hostPlatform.system}.zfs-cachyos.override {
              inherit kernel;
            };
          }
        );
  };
}
