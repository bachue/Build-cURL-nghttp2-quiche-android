#!/bin/bash

# This script builds libcurl+nghttp2+quiche libraries for Android
#
# Credits:
# Bachue Zhou, @bachue
#   https://github.com/bachue/Build-cURL-nghttp2-quiche-android
#

################################################
# EDIT this section to Select Default Versions #
################################################

LIBCURL="7.74.0"    # https://curl.haxx.se/download.html
NGHTTP2="1.41.0"    # https://nghttp2.org/
QUICHE="v0.6.0"     # https://github.com/cloudflare/quiche.git

NDK_VERSION="20b"
ANDROID_EABI_VERSION="4.9"
ANDROID_API_VERSION="21"

# Global flags
buildnghttp2="-2"
buildquiche="-q"
colorflag=""

# Formatting
default="\033[39m"
wihte="\033[97m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${white}\033[1m"
subbold="\033[0m${green}"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

usage ()
{
    echo
    echo -e "${bold}Usage:${normal}"
    echo
    echo -e "  ${subbold}$0${normal} [-k ${dim}<NDK version>${normal}] [-a ${dim}<Android API version>${normal}] [-e ${dim}<EABI version>${normal}] [-c ${dim}<curl version>${normal}] [-n ${dim}<nghttp2 version>${normal}] [-q ${dim}<quiche version>${normal}] [-d] [-f] [-x] [-h]"
    echo
    echo "         -k <version>   Compile with NDK version (default $NDK_VERSION)"
    echo "         -a <version>   Compile with Android API version (default $ANDROID_API_VERSION)"
    echo "         -e <version>   Compile with EABI version (default $ANDROID_EABI_VERSION)"
    echo "         -c <version>   Build curl version (default $LIBCURL)"
    echo "         -n <version>   Build nghttp2 version (default $NGHTTP2)"
    echo "         -q <version>   Build quiche version (default $QUICHE)"
    echo "         -d             Compile without HTTP2 support"
    echo "         -f             Compile without QUICHE support"
    echo "         -x             No color output"
    echo "         -h             Show usage"
    echo
    exit 127
}

while getopts "k:a:e:o:c:n:q:dfxh\?" o; do
    case "${o}" in
        k)
            NDK_VERSION="${OPTARG}"
            ;;
        a)
            ANDROID_API_VERSION="${OPTARG}"
            ;;
        e)
            ANDROID_EABI_VERSION="${OPTARG}"
            ;;
        c)
            LIBCURL="${OPTARG}"
            ;;
        n)
            NGHTTP2="${OPTARG}"
            ;;
        q)
            QUICHE="${OPTARG}"
            ;;
        d)
            buildnghttp2=""
            ;;
        f)
            buildquiche=""
            ;;
        x)
            bold=""
            subbold=""
            normal=""
            dim=""
            alert=""
            alertdim=""
            colorflag="-x"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

## Welcome
echo -e "${bold}Build-cURL-nghttp2-quiche${dim}"
echo "This script builds nghttp2, quiche and libcurl for Android devices."
echo "Targets: x86, x86_64, armv7, armv7s, arm64 and arm64e"
echo

set -e

## NDK Install

if [ ! -f "/tmp/android-ndk-r${NDK_VERSION}-linux-x86_64.zip" ]; then
    wget -c -t 0 --timeout 30 -O "/tmp/android-ndk-r${NDK_VERSION}-linux-x86_64.zip" "https://dl.google.com/android/repository/android-ndk-r$NDK_VERSION-linux-x86_64.zip"
fi
pushd . > /dev/null
cd /tmp
rm -rf "android-ndk-r${NDK_VERSION}"
unzip -qq "android-ndk-r${NDK_VERSION}-linux-x86_64.zip"
pushd . > /dev/null
cd "android-ndk-r${NDK_VERSION}"
export ANDROID_NDK_HOME="$PWD"
popd > /dev/null
popd > /dev/null

## Nghttp2 Build
if [ "$buildnghttp2" == "" ]; then
    NGHTTP2="NONE"
else
    echo
    echo -e "${bold}Building nghttp2 for HTTP2 support${normal}"
    cd nghttp2
    ./nghttp2-build.sh -v "$NGHTTP2" -n "$NDK_VERSION" -a "$ANDROID_API_VERSION" -e "$ANDROID_EABI_VERSION" $colorflag
    cd ..
fi

## Quiche Build
if [ "$buildquiche" == "" ]; then
    QUICHE="NONE"
else
    echo
    echo -e "${bold}Building quiche for HTTP3 support${normal}"
    cd quiche
    ./quiche-build.sh -v "$QUICHE" -n "$NDK_VERSION" -a "$ANDROID_API_VERSION" -e "$ANDROID_EABI_VERSION" $colorflag
    cd ..
fi

## Curl Build
echo
echo -e "${bold}Building Curl${normal}"
cd curl
./libcurl-build.sh -v "$LIBCURL" -n "$NDK_VERSION" -a "$ANDROID_API_VERSION" -e "$ANDROID_EABI_VERSION" $colorflag $buildnghttp2 $buildquiche
cd ..

rm -rf build
for ARCH in x86 x86_64 arm arm64 
do
    RENAME_ARCH="$ARCH"
    if [ "$ARCH" = "arm" ]; then
	RENAME_ARCH="armeabi-v7a"
    fi
    if [ "$ARCH" = "arm64" ]; then
	RENAME_ARCH="arm64-v8a"
    fi
    mkdir -p build/$RENAME_ARCH
    cp nghttp2/$ARCH/lib/libnghttp2.a build/$RENAME_ARCH
    cp quiche/quiche-build/$ARCH/libquiche.a build/$RENAME_ARCH
    cp quiche/quiche-build/$ARCH/openssl/lib/libcrypto.a build/$RENAME_ARCH
    cp quiche/quiche-build/$ARCH/openssl/lib/libssl.a build/$RENAME_ARCH
    cp curl/$ARCH/lib/libcurl.a build/$RENAME_ARCH
done
