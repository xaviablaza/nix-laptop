#!/bin/sh
SSHPASS=FILL_IN_PASSWORD nix --extra-experimental-features nix-command \
--extra-experimental-features flakes run github:nix-community/nixos-anywhere -- \
--generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
--flake ./#nix-laptop \
--env-password \
--target-host administrator@192.168.0.190
