#!/bin/bash

set -e

# arguments:
# --platform <platform> (linux, macos, windows)
# --arch <arch> (arm64, x64)

PLATFORM="macos"
ARCH=$1

if [ -z "$ARCH" ]; then
    ARCH="arm64"
fi

EXT="dylib"
# Determine the platform
case "$(uname -s)" in
Linux*)
    PLATFORM="linux"
    ;;
Darwin*)
    PLATFORM="macos"
    ;;
CYGWIN* | MINGW* | MSYS*) PLATFORM="windows" ;;
*)
    echo "Unsupported platform"
    exit 1
    ;;
esac

case "$PLATFORM" in
"linux")
    EXT="so"
    ;;
"macos")
    EXT="dylib"
    ;;
"windows")
    EXT="dll"
    ;;
*)
    echo "Unsupported PLATFORM $PLATFORM"
    exit 1
    ;;
esac

echo "PLATFORM: $PLATFORM"
echo "ARCH: $ARCH"
echo "EXT: $EXT"

get_absolute_path() {
    local path="$1"
    path="$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"

    echo "$path"
}

join() {
    local result="$1"
    shift
    # check if --not-realpath is set
    if [ "$result" = "--not-realpath" ]; then
        result="$1"
        shift
    fi

    # Determine path separator based on PLATFORM
    case "$PLATFORM" in
    "linux" | "macos")
        separator="/"
        ;;
    "windows")
        separator="\\"
        ;;
    *)
        echo "Unsupported PLATFORM $PLATFORM"
        exit 1
        ;;
    esac

    # Join path segments using the determined separator
    for segment in "$@"; do
        result="${result%/}${separator}${segment#*"$separator"}"
    done

    result=$(get_absolute_path "$result")

    echo "$result"
}

SCRIPTS_RUNNER_DIR=$(join "$(dirname "$0")" "..")
NATIVE_DIR=$(join "$SCRIPTS_RUNNER_DIR" "native")
cd "$NATIVE_DIR" || exit 1

# build the native library
cargo build --release
RELEASE=$(join "$NATIVE_DIR" "target" "release" "libsip_script_runner.$EXT")

cd "$SCRIPTS_RUNNER_DIR" || exit 1
BLOBS_DIR=$(join "$SCRIPTS_RUNNER_DIR" "lib" "src" "blobs")
BLOB_FILE="""$PLATFORM""_""$ARCH"".$EXT"
BLOB_PATH=$(join --not-realpath "$BLOBS_DIR" "$BLOB_FILE")

# copy the native library to the correct location
case "$PLATFORM" in
"linux" | "macos")
    cp "$RELEASE" "$BLOB_PATH" || exit 1
    ;;
"windows")
    copy "$RELEASE" "$BLOB_PATH" || exit 1
    ;;
*)
    echo "Unsupported PLATFORM $PLATFORM"
    exit 1
    ;;
esac

# check for GITHUB_OUTPUT
if [ -z "$GITHUB_OUTPUT" ]; then
    exit 0
fi

echo "Exporting outputs to GITHUB_OUTPUT..."

echo "BLOB_PATH=$BLOB_PATH" >>"$GITHUB_OUTPUT"
echo "BLOB_FILE=$BLOB_FILE" >>"$GITHUB_OUTPUT"
