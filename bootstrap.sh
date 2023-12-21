#!/usr/bin/env bash
read -p "Enter hostname: " -r HOST
sudo -i
nix-shell -p git bitwarden-cli --run "
    git clone https://github.com/JManch/dotfiles.git
    chmod +x ./dotfiles/hosts/$HOST/setup.sh
    ./dotfiles/hosts/$HOST/setup.sh
"
