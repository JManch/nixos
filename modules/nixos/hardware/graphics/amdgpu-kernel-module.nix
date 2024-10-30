# Copied from https://github.com/Atemu/nixos-config/blob/7beb94aec277fb4cbf31360bdbd0a3e9e635a619/modules/amdgpu/kernel-module.nix

# MIT License
#
# Copyright (c) 2021 Atemu
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
{
  lib,
  stdenv,
  kernel, # The kernel to patch
  patches ? [ ],
}:

stdenv.mkDerivation {
  pname = "amdgpu-kernel-module-customised";
  inherit (kernel)
    src
    version
    postPatch
    nativeBuildInputs
    modDirVersion
    ;
  patches = kernel.patches or [ ] ++ patches;

  modulePath = "drivers/gpu/drm/amd/amdgpu";

  buildPhase = ''
    BUILT_KERNEL=${kernel.dev}/lib/modules/$modDirVersion/build

    cp $BUILT_KERNEL/Module.symvers $BUILT_KERNEL/.config ${kernel.dev}/vmlinux ./

    make "-j$NIX_BUILD_CORES" modules_prepare
    make "-j$NIX_BUILD_CORES" M=$modulePath modules
  '';

  installPhase = ''
    make \
      INSTALL_MOD_PATH="$out" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M="$modulePath" \
      INSTALL_MOD_STRIP=1 \
      modules_install
  '';

  meta = {
    description = "AMDGPU kernel module";
    license = lib.licenses.gpl2Only;
  };
}
