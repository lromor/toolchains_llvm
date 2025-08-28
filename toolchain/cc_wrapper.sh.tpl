#!/bin/sh
#
# Copyright 2021 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# shellcheck disable=SC1083

set -eu

CLEANUP_FILES=""

cleanup() {
  for f in ${CLEANUP_FILES}; do
    [ -n "${f}" ] && rm -f "${f}"
  done
}

trap cleanup EXIT

# See note in toolchain/internal/configure.bzl where we define
# `wrapper_bin_prefix` for why this wrapper is needed.

# this script is located at either
# - <execroot>/external/<repo_name>/bin/cc_wrapper.sh
# - <runfiles>/<repo_name>/bin/cc_wrapper.sh
# The clang is located at
# - <execroot>/external/<repo_name2>/bin/clang
# - <runfiles>/<repo_name2>/bin/clang
#
# In both cases, getting to clang can be done via
# Finding the current dir of this script,
# - <execroot>/external/<repo_name>/bin/
# - <runfiles>/<repo_name>/bin/
# going back 2 directories
# - <execroot>/external
# - <runfiles>
#
# Going into %{toolchain_path_prefix} without the `external/` prefix + `bin/clang`
#

dirname_shim() {
  path="$1"
  # Remove trailing slashes
  while [ "${path%/}" != "${path}" ]; do path=${path%/}; done
  case "${path}" in
    */*) path=${path%/*}; [ -n "${path}" ] || path="/"; echo "${path}" ;;
    *) echo "." ;;
  esac
}

script_dir=$(dirname_shim "$0")
toolchain_path_prefix="%{toolchain_path_prefix}"

# Sometimes this path may be an absolute path in which case we dont do anything because
# This is using the host toolchain to build.
case "${toolchain_path_prefix}" in
  /*) ;;
  *) toolchain_path_prefix="${script_dir}/../../${toolchain_path_prefix#external/}" ;;
esac

if [ ! -f "${toolchain_path_prefix}bin/clang" ]; then
  echo >&2 "ERROR: could not find clang; PWD=\"${PWD}\"; PATH=\"${PATH}\"; toolchain_path_prefix=${toolchain_path_prefix}."
  exit 5
fi

OUTPUT=
expect_output=0

parse_option() {
  opt="$1"
  if [ "${expect_output}" = 1 ]; then
    OUTPUT=${opt}
    expect_output=0
  elif [ "${opt}" = "-o" ]; then
    expect_output=1
  fi
}

sanitize_option() {
  opt=$1
  case "${opt}" in
    */cc_wrapper.sh)
      printf "%s" "${toolchain_path_prefix}bin/clang" ;;
    -fsanitize-ignorelist=*|-fsanitize-blacklist=*)
      val=${opt#*=}
      name=${opt%%=*}
      case "${val}" in
        /*) printf "%s" "${opt}" ;;
        *) case "${script_dir}" in
             /*) printf "%s" "${name}=${script_dir}/../../../${val}" ;;
             *) printf "%s" "${opt}" ;;
           esac ;;
      esac ;;
    *) printf "%s" "${opt}" ;;
  esac
}

# Build the sanitized command line.
# Snapshot original arguments first.
origc=0
for a in "$@"; do
  origc=$((origc + 1))
  eval "orig_${origc}=\$a"
done

# Start new args with the compiler path
set -- "${toolchain_path_prefix}bin/clang"

i=1
while [ "$i" -le "$origc" ]; do
  eval "arg=\${orig_${i}}"
  case "${arg}" in
    @*)
      file=${arg#@}
      if [ -r "${file}" ]; then
        tmpfile=$(mktemp)
        CLEANUP_FILES="${CLEANUP_FILES} ${tmpfile}"
        while IFS= read -r opt; do
          sopt=$(sanitize_option "${opt}")
          parse_option "${sopt}"
          printf "%s\n" "${sopt}" >>"${tmpfile}"
        done <"${file}"
        set -- "$@" "@${tmpfile}"
      else
        sarg=$(sanitize_option "${arg}")
        parse_option "${sarg}"
        set -- "$@" "${sarg}"
      fi
      ;;
    *)
      sarg=$(sanitize_option "${arg}")
      parse_option "${sarg}"
      set -- "$@" "${sarg}"
      ;;
  esac
  i=$((i + 1))
done

# Call the C++ compiler.
"$@"

# Generate an empty file if header processing succeeded.
case "${OUTPUT}" in
  *.h.processed) : >"${OUTPUT}" ;;
esac
