{ pkgs ? import <nixpkgs> {} }:

with pkgs;

stdenv.mkDerivation {
  name = "osx-kvm-host-cpu-env";
  buildInputs = [
    binutils
    curl
    dmg2img
    gnumake
    gptfdisk
    kvm
    unzip
    qemu-utils
  ];
}
