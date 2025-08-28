# Changelog

## 2025-08-28 — POSIX /bin/sh compatibility

- Convert wrapper and utility scripts to POSIX-compliant `/bin/sh`.
  - `toolchain/cc_wrapper.sh.tpl`:
    - Shebang switched to `/bin/sh`; use `set -eu`.
    - Removed bashisms: arrays, `[[ ]]`, `function`, `local`, arithmetic for-loops, `${!i}`, regex `=~`.
    - POSIX-safe argument parsing; supports `@file` by rewriting into temp files and cleaning them up.
    - POSIX `dirname_shim` and path handling; direct call to `clang`.
    - Replaced `echo -n > file` with `: > file`.
  - `toolchain/osx_cc_wrapper.sh.tpl`:
    - Shebang switched to `/bin/sh`; use `set -eu`.
    - Removed bashisms and `BASH_SOURCE` usage.
    - POSIX `parse_option` for `-l*`, `-L*`, `@loader_path/*`, `-Wl,-rpath,@loader_path/*`.
    - POSIX `sanitize_option`; map `-fuse-ld=ld64.lld` to `--ld-path=.../ld64.lld`; emit `-fuse-ld=lld` in `@file`.
    - Ensure `/usr/bin` is present in `PATH` using POSIX `case`.
    - Rewrote helper functions with POSIX `[ ]` and safe `readlink` loop.
    - Replaced `echo -n > file` with `: > file`.
  - `utils/llvm_checksums.sh`:
    - Shebang switched to `/bin/sh`; use `set -eu`.
    - Replaced `[[ ]]` and arithmetic `(( ))` with POSIX `[ ]`.
    - Usage now references `$0` instead of `${BASH_SOURCE[0]}`.

- Validation: all three scripts pass `sh -n` syntax checks.

