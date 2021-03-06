#!/bin/bash

UNAME_S=$(uname -s)
UNAME_SM=$(uname -sm)
echo "build on $UNAME_SM"

echo "ANDROID_SDK=$ANDROID_SDK"
echo "ANDROID_NDK=$ANDROID_NDK"

if [ -z "$ANDROID_NDK" -o -z "$ANDROID_SDK" ]; then
    echo "You must define ANDROID_NDK, ANDROID_SDK before starting."
    echo "They must point to your NDK and SDK directories."
    echo ""
    exit 1
fi

#--------------------
# common defines
ARCH=$1
if [ -z "$ARCH" ]; then
    echo "You must specific an architecture 'arm, armv7a, x86, ...'."
    echo ""
    exit 1
fi

source ./android-toolchain-build.sh $ARCH 
SYSROOT=$TOOLCHAIN_PATH/sysroot

echo $TOOLCHAIN_PATH
echo $ANDROID_PLATFORM
echo $CROSS_PREFIX

export PATH=$TOOLCHAIN_PATH/bin:$TOOLCHAIN_PATH/$CROSS_PREFIX/bin:$PATH
echo $PATH

export CC="${CROSS_PREFIX}-gcc --sysroot=$SYSROOT"
export ADDR2LINE=${CROSS_PREFIX}-addr2line
export AR=${CROSS_PREFIX}-ar
#export AS=${CROSS_PREFIX}-as 关闭时AS自动使用gcc, 打开后编译不成功
export CPP=${CROSS_PREFIX}-cpp
export DWP=${CROSS_PREFIX}-dwp
export ELFEDIT=${CROSS_PREFIX}-elfedit
export CXX=${CROSS_PREFIX}-g++
export GCOV=${CROSS_PREFIX}-gcov
export GDB=${CROSS_PREFIX}-gdb
export GPROF=${CROSS_PREFIX}-gprof
export LD=${CROSS_PREFIX}-ld
export NM=${CROSS_PREFIX}-nm
export OBJCOPY=${CROSS_PREFIX}-objcopy
export OBJDUMP=${CROSS_PREFIX}-objdump
export RANLIB=${CROSS_PREFIX}-ranlib
export READELF=${CROSS_PREFIX}-readelf
export SIZE=${CROSS_PREFIX}-size
export STRINGS=${CROSS_PREFIX}-strings
export STRIP=${CROSS_PREFIX}-strip


EXTRA_CFLAGS=
EXTRA_LDFLAGS=
DEP_LIBS=

MAKEFLAGS=
if which nproc >/dev/null
then
    MAKEFLAGS=-j`nproc`
elif [ "$UNAMES" = "Darwin" ] && which sysctl >/dev/null
then
    MAKEFLAGS=-j`sysctl -n machdep.cpu.thread_count`
fi

#----- armv7a begin -----
if [ "$ARCH" = "armv7a" ]; then
    HOST=arm-linux

    EXTRA_CFLAGS="$EXTRA_CFLAGS -march=armv7-a -mcpu=cortex-a8 -mfpu=vfpv3-d16 -mfloat-abi=softfp -mthumb"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS -Wl,--fix-cortex-a8"
    CFG_FLAGS="$CFG_FLAGS --enable-asm"

elif [ "$ARCH" = "armv5" ]; then
    HOST=arm-linux

    EXTRA_CFLAGS="$EXTRA_CFLAGS -march=armv5te -mtune=arm9tdmi -msoft-float"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS"
    CFG_FLAGS="$CFG_FLAGS --disable-asm" # asm与此架构不兼容

elif [ "$ARCH" = "x86" ]; then
    HOST=i686-linux

    EXTRA_CFLAGS="$EXTRA_CFLAGS -march=atom -msse3 -ffast-math -mfpmath=sse"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS"
    CFG_FLAGS="$CFG_FLAGS --enable-asm"

elif [ "$ARCH" = "x86_64" ]; then

    EXTRA_CFLAGS="$EXTRA_CFLAGS"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS"
    CFG_FLAGS="$CFG_FLAGS --enable-asm"

elif [ "$ARCH" = "arm64" ]; then

    EXTRA_CFLAGS="$EXTRA_CFLAGS"
    EXTRA_LDFLAGS="$EXTRA_LDFLAGS"
    CFG_FLAGS="$CFG_FLAGS --enable-asm"

else
    echo "unknown architecture $ARCH";
    exit 1
fi

BUILD_ROOT=`pwd`
PROJECT_DIR=x264
PREFIX=$BUILD_ROOT/build/$PROJECT_DIR/$ARCH
mkdir -p $PREFIX

CFG_FLAGS="$CFG_FLAGS --prefix=${PREFIX}"
CFG_FLAGS="$CFG_FLAGS --cross-prefix=${CROSS_PREFIX}-"
CFG_FLAGS="$CFG_FLAGS --host="$HOST""
CFG_FLAGS="$CFG_FLAGS --enable-static"
#CFG_FLAGS="$CFG_FLAGS --enable-shared"
CFG_FLAGS="$CFG_FLAGS --disable-cli"
CFG_FLAGS="$CFG_FLAGS --enable-pic"
#CFG_FLAGS="$CFG_FLAGS --disable-asm" # 旧版本打开asm后会产生TEXTREL信息, 导致Android 6.0上动态库载入失败

EXT_CFLAGS="-O3 -Wall -pipe \
    -std=c99 \
    -ffast-math \
    -fstrict-aliasing -Werror=strict-aliasing \
    -Wno-psabi -Wa,--noexecstack " 

cd $BUILD_ROOT/$PROJECT_DIR
./configure $CFG_FLAGS \
  --extra-cflags="$EXTCFLAGS $EXTRA_CFLAGS" \
  --extra-ldflags="$DEP_LIBS $EXTRA_LDFLAGS"

#--------------------
echo ""
echo "--------------------"
echo "[*] compile $PROJECT_DIR"
echo "--------------------"
make clean
make $MAKEFLAGS -j8 
make install

