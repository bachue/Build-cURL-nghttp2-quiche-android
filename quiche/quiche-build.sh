#!/bin/bash
# This script downloads and builds the Android quiche library
#
# Credits:
#
# Bachue Zhou, @bachue
#   https://github.com/bachue/Build-cURL-nghttp2-quiche-android
# QUICHE - https://github.com/cloudflare/quiche.git
#

# > quiche is an implementation of the QUIC transport protocol 
# > and HTTP/3 as specified by the IETF.

set -e

# Formatting
default="\033[39m"
wihte="\033[97m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${green}\033[1m"
subbold="\033[0m${green}"
archbold="\033[0m${yellow}\033[1m"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

# set trap to help debug build errors
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/quiche*.log${alertdim}"; tail -n 3 /tmp/quiche*.log' INT TERM EXIT

QUICHE_VERNUM="v0.9.0/test/send_ping"
NDK_VERSION="20b"
ANDROID_EABI_VERSION="4.9"
ANDROID_API_VERSION="21"

usage ()
{
    echo
    echo -e "${bold}Usage:${normal}"
    echo
    echo -e "  ${subbold}$0${normal} [-v ${dim}<quiche version>${normal}] [-a ${dim}<Android API version>${normal}] [-n ${dim}<NDK version>${normal}] [-e ${dim}<EABI version>${normal}] [-x] [-h]"
    echo
    echo "         -v   version of quiche (default $QUICHE_VERNUM)"
    echo "         -n   NDK version (default $NDK_VERSION)"
    echo "         -a   Android API version (default $ANDROID_API_VERSION)"
    echo "         -e   EABI version (default $ANDROID_EABI_VERSION)"
    echo "         -x   disable color output"
    echo "         -h   show usage"
    echo
    trap - INT TERM EXIT
    exit 127
}

while getopts "v:n:a:e:xh\?" o; do
    case "${o}" in
        v)
            QUICHE_VERNUM="${OPTARG}"
            ;;
        n)
            NDK_VERSION="${OPTARG}"
            ;;
        a)
            ANDROID_API_VERSION="${OPTARG}"
            ;;
        e)
            ANDROID_EABI_VERSION="${OPTARG}"
            ;;
        x)
            bold=""
            subbold=""
            normal=""
            dim=""
            alert=""
            alertdim=""
            archbold=""
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "ANDROID_NDK_HOME must be set" >&2
    exit 1
fi

QUICHE_VERSION="quiche-${QUICHE_VERNUM}"
QUICHE="${PWD}/../quiche"

checkTool() {
    TOOL=$1
    PKG=$2

    if (type "$1" > /dev/null) ; then
        echo "  $2 already installed"
    else
        echo -e "${alertdim}** WARNING: $2 not installed... attempting to install.${dim}"

        if ! type "apt" > /dev/null; then
            echo -e "${alert}** FATAL ERROR: apt not installed - unable to install $2 - exiting.${normal}"
            exit
        else
            echo "  apt installed - using to install $2"
            apt install -yqq "$2"
        fi

        # Check to see if installation worked
        if (type "$1" > /dev/null) ; then
            echo "  SUCCESS: $2 installed"
        else
            echo -e "${alert}** FATAL ERROR: $2 failed to install - exiting.${normal}"
            exit
        fi
    fi
}
checkTool curl curl
checkTool git git
checkTool cmake cmake

checkRust() {
    if (type "rustup" > /dev/null); then
        echo "  rustup already installed"
    else
        echo -e "${alertdim}** WARNING: rustup not installed... attempting to install.${dim}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        if (type "rustup" > /dev/null); then
            echo "  SUCCESS: rustup installed"
        else
            echo -e "${alert}** FATAL ERROR: rustup failed to install - exiting.${normal}"
            exit
        fi
    fi
    rustup target add aarch64-linux-android \
                      arm-linux-androideabi \
		      armv7-linux-androideabi \
                      i686-linux-android \
                      x86_64-linux-android
    cargo install cargo-ndk -q
}
checkRust

buildAndroid() {
    ARCH=$1
    TARGET=$2
 
    echo -e "${subbold}Building ${QUICHE} for ${archbold}${ARCH}${dim}"

    pushd . > /dev/null
    cd quiche
    cargo ndk -t "$TARGET" -p "$ANDROID_API_VERSION" -- build --release --features ffi,pkg-config-meta,qlog >> "/tmp/${QUICHE_VERSION//\//-}-${ARCH}.log" 2>&1
    popd > /dev/null

    mkdir -p "quiche-build/${ARCH}/"
    cp -r quiche/deps/boringssl/src "quiche-build/${ARCH}/openssl"
    mkdir -p "quiche-build/${ARCH}/openssl/lib"
    cp "quiche/target/${TARGET}/release/libquiche.a" "quiche-build/${ARCH}"
    cp "quiche/target/${TARGET}/release/libquiche.so" "quiche-build/${ARCH}"
    cp "quiche/target/release/quiche.pc" "quiche-build/${ARCH}"
    sed -i "s/libdir=.*/libdir=${PWD//\//\\/}\/quiche-build\/${ARCH}/" "quiche-build/${ARCH}/quiche.pc"
    cp $(find "quiche/target/${TARGET}/release/" -type f -name libssl.a -o -type f -name libcrypto.a) "quiche-build/${ARCH}/openssl/lib"
}

echo -e "${bold}Cleaning up${dim}"
rm -rf quiche-build /tmp/${QUICHE_VERSION//\//-}-*

if [ ! -e quiche ]; then
    echo "Cloning quiche"
    git clone -b "$QUICHE_VERNUM" --recursive https://github.com/bachue/quiche.git
else
    echo "Using quiche"
    (
        cd quiche 
        git fetch
        git reset --hard "$QUICHE_VERNUM"
        cargo clean
    )
fi

echo "** Building ${QUICHE_VERSION} **"
buildAndroid x86 i686-linux-android
buildAndroid x86_64 x86_64-linux-android
buildAndroid arm armv7-linux-androideabi
buildAndroid arm64 aarch64-linux-android

#reset trap
trap - INT TERM EXIT

echo -e "${normal}Done"
