#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Bilibili
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#----------
# modify for your build tool

FF_ALL_ARCHS_IOS6_SDK="armv7 armv7s i386"
FF_ALL_ARCHS_IOS7_SDK="armv7 armv7s arm64 i386 x86_64"
FF_ALL_ARCHS_IOS8_SDK="armv7 arm64 i386 x86_64"

FF_ALL_ARCHS_CUSTOM="arm64-simulator armv7 arm64 i386 x86_64"

FF_ALL_ARCHS=$FF_ALL_ARCHS_CUSTOM

#----------
UNI_BUILD_ROOT=$(pwd)
UNI_TMP="$UNI_BUILD_ROOT/tmp"
UNI_TMP_LLVM_VER_FILE="$UNI_TMP/llvm.ver.txt"
FF_TARGET=$1
FF_TARGET_EXTRA=$2
set -e

#----------
echo_archs() {
    echo "===================="
    echo "[*] check xcode version"
    echo "===================="
    echo "FF_ALL_ARCHS = $FF_ALL_ARCHS"
}

FF_LIBS="libavcodec libavfilter libavformat libavutil libswscale libswresample"
do_lipo_ffmpeg () {
    LIB_FILE=$1
    LIPO_SIMULATOR_FLAGS=
    LIPO_IPHONE_FLAGS=
    LIPO_IPHONE_OUTPUT_HEADERS="$UNI_BUILD_ROOT/build/universal/iphone"
    LIPO_SIMULAROR_OUTPUT_HEADERS="$UNI_BUILD_ROOT/build/universal/simulator"

    mkdir -p $LIPO_IPHONE_OUTPUT_HEADERS
    mkdir -p $LIPO_SIMULAROR_OUTPUT_HEADERS

    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/lib/$LIB_FILE.a"
        ARCH_LIB_HEADER="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/include/$LIB_FILE"
        if [[ "${ARCH}" == "arm64" || "${ARCH}" == "armv7" ]]; then
            LIPO_IPHONE_FLAGS="$LIPO_IPHONE_FLAGS $ARCH_LIB_FILE"
        fi

        if [[ "${ARCH}" == "arm64-simulator" || "${ARCH}" == "x86_64" || "${ARCH}" == "i386" ]]; then
            LIPO_SIMULATOR_FLAGS="$LIPO_SIMULATOR_FLAGS $ARCH_LIB_FILE"
            cp -rf $ARCH_LIB_HEADER $LIPO_IPHONE_OUTPUT_HEADERS
        fi
        
        echo "$ARCH_LIB_FILE"
    done

    echo "lipo simulator flags: $LIPO_SIMULATOR_FLAGS"
    echo "lipo iphone flags: $LIPO_IPHONE_FLAGS"

    LIPO_IPHONE_OUTPUT_LIB="$UNI_BUILD_ROOT/build/universal/iphone/$LIB_FILE.a"
    LIPO_SIMULATOR_OUTPUT_LIB="$UNI_BUILD_ROOT/build/universal/simulator/$LIB_FILE.a"

    xcrun lipo -create $LIPO_IPHONE_FLAGS -output $LIPO_IPHONE_OUTPUT_LIB
    xcrun lipo -create $LIPO_SIMULATOR_FLAGS -output $LIPO_SIMULATOR_OUTPUT_LIB

    xcodebuild -create-xcframework -library $LIPO_IPHONE_OUTPUT_LIB -library $LIPO_SIMULATOR_OUTPUT_LIB -output $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE.xcframework
}

SSL_LIBS="libcrypto libssl"
do_lipo_ssl () {
    LIB_FILE=$1
    LIPO_FLAGS=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_LIB_FILE="$UNI_BUILD_ROOT/build/openssl-$ARCH/output/lib/$LIB_FILE"
        if [ -f "$ARCH_LIB_FILE" ]; then
            LIPO_FLAGS="$LIPO_FLAGS $ARCH_LIB_FILE"
        else
            echo "skip $LIB_FILE of $ARCH";
        fi
    done

    if [ "$LIPO_FLAGS" != "" ]; then
        xcrun lipo -create "$LIPO_FLAGS -output $UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE"
        xcrun lipo -info "$UNI_BUILD_ROOT/build/universal/lib/$LIB_FILE"
    fi
}

do_lipo_all () {
    mkdir -p "$UNI_BUILD_ROOT/build/universal/lib"
    echo "lipo archs: $FF_ALL_ARCHS"
    for FF_LIB in $FF_LIBS
    do
        do_lipo_ffmpeg "$FF_LIB";
    done

    ANY_ARCH=
    for ARCH in $FF_ALL_ARCHS
    do
        ARCH_INC_DIR="$UNI_BUILD_ROOT/build/ffmpeg-$ARCH/output/include"
        if [ -d "$ARCH_INC_DIR" ]; then
            if [ -z "$ANY_ARCH" ]; then
                ANY_ARCH=$ARCH
                cp -R "$ARCH_INC_DIR" "$UNI_BUILD_ROOT/build/universal/"
            fi

            UNI_INC_DIR="$UNI_BUILD_ROOT/build/universal/include"

            mkdir -p "$UNI_INC_DIR/libavutil/$ARCH"
            cp -f "$ARCH_INC_DIR/libavutil/avconfig.h"  "$UNI_INC_DIR/libavutil/$ARCH/avconfig.h"
            cp -f tools/avconfig.h                      "$UNI_INC_DIR/libavutil/avconfig.h"
            cp -f "$ARCH_INC_DIR/libavutil/ffversion.h" "$UNI_INC_DIR/libavutil/$ARCH/ffversion.h"
            cp -f tools/ffversion.h                     "$UNI_INC_DIR/libavutil/ffversion.h"
            mkdir -p "$UNI_INC_DIR/libffmpeg/$ARCH"
            cp -f "$ARCH_INC_DIR/libffmpeg/config.h"    "$UNI_INC_DIR/libffmpeg/$ARCH/config.h"
            cp -f tools/config.h                        "$UNI_INC_DIR/libffmpeg/config.h"
        fi
    done

    # for SSL_LIB in $SSL_LIBS
    # do
    #     do_lipo_ssl "$SSL_LIB.a";
    # done
}

#----------
if [ "$FF_TARGET" = "armv7" -o "$FF_TARGET" = "armv7s" -o "$FF_TARGET" = "arm64" ]; then
    echo_archs
    sh tools/do-compile-ffmpeg.sh $FF_TARGET $FF_TARGET_EXTRA
    do_lipo_all
elif [ "$FF_TARGET" = "i386" -o "$FF_TARGET" = "x86_64" ]; then
    echo_archs
    sh tools/do-compile-ffmpeg.sh $FF_TARGET $FF_TARGET_EXTRA
    do_lipo_all
elif [ "$FF_TARGET" = "lipo" ]; then
    echo_archs
    do_lipo_all
elif [ "$FF_TARGET" = "all" ]; then
    echo_archs
    for ARCH in $FF_ALL_ARCHS
    do
        echo "do-compile $ARCH $FF_TARGET_EXTRA"
        sh tools/do-compile-ffmpeg.sh $ARCH $FF_TARGET_EXTRA
    done

    do_lipo_all
elif [ "$FF_TARGET" = "check" ]; then
    echo_archs
elif [ "$FF_TARGET" = "clean" ]; then
    echo_archs
    echo "=================="
    for ARCH in $FF_ALL_ARCHS
    do
        echo "clean ffmpeg-$ARCH"
        echo "=================="
        cd ffmpeg-$ARCH && git clean -xdf && cd -
    done
    echo "clean build cache"
    echo "================="
    rm -rf build/ffmpeg-*
    rm -rf build/openssl-*
    rm -rf build/universal/include
    rm -rf build/universal/lib
    echo "clean success"
else
    echo "Usage:"
    echo "  compile-ffmpeg.sh armv7|arm64|i386|x86_64"
    echo "  compile-ffmpeg.sh armv7s (obselete)"
    echo "  compile-ffmpeg.sh lipo"
    echo "  compile-ffmpeg.sh all"
    echo "  compile-ffmpeg.sh clean"
    echo "  compile-ffmpeg.sh check"
    exit 1
fi