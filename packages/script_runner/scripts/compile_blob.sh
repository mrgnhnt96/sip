#!/bin/bash

# arguments:
# --platform <platform> (linux, macos, windows)
# --arch <arch> (arm64, x64)

PLATFORM="macos"
ARCH="arm64"
EXT="dylib"
while [[ $# -gt 0 ]]; do
    case "$1" in
    --platform)
        PLATFORM="$2"
        shift
        ;;
    --arch)
        ARCH="$2"
        shift
        ;;
    *)
        echo "Unknown argument $1"
        exit 1
        ;;
    esac
    shift
done

case "$PLATFORM" in
"linux") EXT="so" ;;
"macos") EXT="dylib" ;;
"windows") EXT="dll" ;;
*)
    echo "Unsupported PLATFORM $PLATFORM"
    exit 1
    ;;
esac

echo "PLATFORM: $PLATFORM"
echo "ARCH: $ARCH"
echo "EXT: $EXT"

join() {
    local result=""
    # check if --not-realpath is set
    if [[ "$1" == "--not-realpath" ]]; then
        shift
        result="$1"
        shift
    else
        result=$(realpath "$1")
        shift
    fi

    # Determine path separator based on PLATFORM
    case "$PLATFORM" in
    "linux" | "macos") separator="/" ;;
    "windows") separator="\\" ;;
    *)
        echo "Unsupported PLATFORM $PLATFORM"
        exit 1
        ;;
    esac

    # Join path segments using the determined separator
    for segment in "$@"; do
        result="${result%/}${separator}${segment#*"$separator"}"
    done

    echo "$result"
}

SCRIPTS_DIR=$(join "$(dirname "$0")" "..")

# make sure cargo is installed
if ! command -v cargo &>/dev/null; then
    echo "cargo is not installed"
    echo "Please install rustup and cargo"
    echo "https://doc.rust-lang.org/cargo/getting-started/installation.html"
    exit 1
fi

NATIVE_DIR=$(join "$SCRIPTS_DIR" "native")
cd "$NATIVE_DIR" || exit 1

# build the native library
cargo build --release
RELEASE=$(join "$NATIVE_DIR" "target" "release" "libsip_script_runner.$EXT")

cd "$SCRIPTS_DIR" || exit 1
BLOBS_DIR=$(join "$SCRIPTS_DIR" "lib" "src" "blobs")
BLOB_FILE=$(join --not-realpath "$BLOBS_DIR" """$PLATFORM""_""$ARCH"".$EXT")

# copy the native library to the correct location
case "$PLATFORM" in
"linux" | "macos")
    cp "$RELEASE" "$BLOB_FILE" || exit 1
    ;;
"windows")
    copy "$RELEASE" "$BLOB_FILE" || exit 1
    ;;
*)
    echo "Unsupported PLATFORM $PLATFORM"
    exit 1
    ;;
esac
