{
  description = "Bazel LLVM toolchain module patched for nixos";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = import nixpkgs {
              system = system;
            }; in
          {
            devShells.default = pkgs.callPackage ./shell.nix {};
            packages.default = pkgs.stdenv.mkDerivation {
              name = "toolchains_llvm";
              version = "1.2.0";
              src = ./.;
              patches = [
                (pkgs.substituteAll {
                  src = ./add-nixos.patch;
                  linuxHeadersPath = pkgs.linuxHeaders;
                  glibcPath = pkgs.stdenv.cc.libc;
                  glibcDevPath = pkgs.stdenv.cc.libc_dev;
                })
              ];
              postPatch = ''
                patchShebangs .
              '';
              installPhase = ''
                cp -r . $out
              '';
            };
          }
      );
}
