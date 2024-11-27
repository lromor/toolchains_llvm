{
  mkShell,
  zlib,
  bazel,
  stdenv
}:
mkShell {
  packages = [
    bazel
    zlib
  ];

