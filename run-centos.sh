#!/usr/bin/env bash

##
# Script de compilation ffmpeg avec les modules qui vont bien
#
# à exécuter en root dans un container docker
#
# @see https://gist.github.com/Brainiarc7/3f7695ac2a0905b05c5b
# @see https://gist.github.com/silverkorn/d27861c9406a73a7bd4b
#
# docker run --rm --name centos-ffmpeg --mount type=bind,source=$HOME/workspace/ffmpeg,target=/ffmpeg -w /ffmpeg -it centos
#
# version CentOS
#
# Buts:
# - build static et dynamic
#
# Versions:
# - NASM 2.14.02 (utile que pour lame ?)
# - Yasm 1.3.0
#
# Modules activés :
# - libfdk_aac (Fraunhofer FDK AAC)
# - libass (sous-titrage)
# - libx264
# - libfreetype (pour drawtext)
# - libfontconfig (fallback font par défaut)
#
# note: ffplay requiert libsdl2-dev
##

SRC_PATH=/root/centos/ffmpeg_sources
BUILD_PATH=/root/centos/ffmpeg_build
BIN_PATH=/root/centos/bin
CPU_COUNT=$(nproc)
FFMPEG_ENABLE="--enable-gpl --enable-nonfree"

[ ! -d "$SRC_PATH" ] && mkdir -pv "$SRC_PATH"
[ ! -d "$BUILD_PATH" ] && mkdir -pv "$BUILD_PATH"
[ ! -d "$BIN_PATH" ] && mkdir -pv "$BIN_PATH"

# Téléchargement et décompression de toutes les dépendances externes
# à jour au 01/06/2019

##
# libSDL2 nécessaire pour compiler ffplay
# note: pas dispo dans base ni epel
##
installLibSDL2() {
  echo "* installLibSDL2"
  cd "$SRC_PATH" || return
  if [ ! -d "SDL2-2.0.9" ]; then
    curl -O -L http://www.libsdl.org/release/SDL2-2.0.9.tar.gz && \
    tar fvxz SDL2-2.0.9.tar.gz && \
    rm tar fvxz SDL2-2.0.9.tar.gz
  fi
  cd SDL2-2.0.9 && \
  PATH="$BIN_PATH:$PATH" ./configure --prefix="$BUILD_PATH" --bindir="$BIN_PATH" --enable-static && \
  make -j "${CPU_COUNT}" && \
  make install
}

##
# activer ffplay
##
enableFfplay() {
  echo "* enableFfplay"
  installLibSDL2
  FFMPEG_ENABLE="${FFMPEG_ENABLE} --enable-ffplay"
}

##
# désactiver ffplay
##
disableFfplay() {
  echo "* disableFfplay"
  FFMPEG_ENABLE="${FFMPEG_ENABLE} --disable-ffplay"
}

##
# NASM : que pour liblame ??
# note: compilation indispensable car CentOS 7 est fourni avec NASM 2.10 et ffmpeg requiert >= 2.13
##
installNASM() {
  echo "* installNASM"
  cd "$SRC_PATH" || return
  if [ ! -d "nasm-2.14.02" ]; then
    curl -O -L https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2 && \
    tar xjvf nasm-2.14.02.tar.bz2 && \
    rm nasm-2.14.02.tar.bz2
  fi
  cd nasm-2.14.02 && \
  ./autogen.sh && \
  PATH="$BIN_PATH:$PATH" ./configure --prefix="$BUILD_PATH" --bindir="$BIN_PATH" && \
  make -j "${CPU_COUNT}" && \
  make install
}

##
# Yasm
# note: version 1.2.0-4.el7 dans epel (= minimum requis par ffmpeg)
##
installYasm() {
  echo "* install Yasm"
  cd "$SRC_PATH" || return
  if [ ! -d "yasm-1.3.0" ]; then
    curl -O -L http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz && \
    tar xzvf yasm-1.3.0.tar.gz && \
    rm yasm-1.3.0.tar.gz
  fi
  cd yasm-1.3.0 && \
  PATH="$BIN_PATH:$PATH" ./configure --prefix="$BUILD_PATH" --bindir="$BIN_PATH" && \
  make -j "${CPU_COUNT}" && \
  make install
}

##
# libx264
# note: pas dispo dans base ni epel
##
installLibX264() {
  echo "* installLibX264"
  cd "$SRC_PATH" || return
  if [ ! -d "x264" ]; then
    git clone --depth 1 https://code.videolan.org/videolan/x264.git
  fi
  cd x264 && \
  PATH="$BIN_PATH:$PATH" PKG_CONFIG_PATH="$BUILD_PATH/lib/pkgconfig" ./configure --prefix="$BUILD_PATH" --bindir="$BIN_PATH" --enable-static
  PATH="$BIN_PATH:$PATH" make -j "${CPU_COUNT}" && \
  make install
}

##
#
##
enableLibX264() {
  echo "* enableLibX264"
  FFMPEG_ENABLE="${FFMPEG_ENABLE} --enable-libx264"
}

##
#
##
installLibX265() {
  echo "* installLibX265"
  cd "$SRC_PATH" || return
  if [ ! -d "x265" ]; then
    hg clone https://bitbucket.org/multicoreware/x265
  fi
  cd x265/build/linux && \
  PATH="$BIN_PATH:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$BUILD_PATH" -DENABLE_SHARED:bool=off ../../source && \
  PATH="$BIN_PATH:$PATH" make -j "${CPU_COUNT}" && \
  make install
}

##
#
##
enableLibX265() {
  echo "* enableLibX265"
  FFMPEG_ENABLE="${FFMPEG_ENABLE} --enable-libx265"
}

##
# fdk_aac
# note: pas dispo dans base ni epel
##
installLibFdkAac() {
  echo "* installLibFdkAac"
  cd "$SRC_PATH" || return
  if [ ! -d "fdk-aac" ]; then
    git clone --depth 1 https://github.com/mstorsjo/fdk-aac
  fi
  cd fdk-aac && \
  autoreconf -fiv && \
  ./configure --prefix="$BUILD_PATH" --disable-shared && \
  make -j "${CPU_COUNT}" && \
  make install
}

##
#
##
enableLibFdkAac() {
  echo "* enableLibFdkAac"
  FFMPEG_ENABLE="${FFMPEG_ENABLE} --enable-libfdk_aac"
}

##
# fribidi nécessaire à libass
# note: version 1.0.2-1.el7 dans base
##
installFribidi() {
  echo "* installFribidi"
  cd "$SRC_PATH" || return
  if [ ! -d "fribidi-1.0.1" ]; then
    curl -O -L https://github.com/fribidi/fribidi/releases/download/v1.0.1/fribidi-1.0.1.tar.bz2
    tar xjvf fribidi-1.0.1.tar.bz2 && \
    rm fribidi-1.0.1.tar.bz2
  fi
  cd fribidi-1.0.1 && \
  PATH="$BIN_PATH:$PATH" ./configure --prefix="${BUILD_PATH}" --bindir="${BIN_PATH}" --disable-shared --enable-static && \
  make -j "${CPU_COUNT}" && \
  make install
}

##
# libass
# options possibles: --disable-fontconfig, --disable-static
# note: dans epel, version 0.13.4-6.el7
##
installLibAss() {
  echo "* installLibAss"

  installFribidi

  cd "$SRC_PATH" || return
  if [ ! -d "libass" ]; then
    git clone https://github.com/libass/libass.git
  fi

  cd libass && \
  ./autogen.sh && \
  PATH="$BIN_PATH:$PATH" PKG_CONFIG_PATH="$BUILD_PATH/lib/pkgconfig" ./configure --prefix="$BUILD_PATH" --bindir="$BIN_PATH" --disable-shared --enable-static --disable-require-system-font-provider && \
  PATH="$BIN_PATH:$PATH" make -j "${CPU_COUNT}" && \
  make install
}

##
#
##
enableLibAss() {
  echo "* enableLibAss"
  FFMPEG_ENABLE="${FFMPEG_ENABLE} --enable-libfribidi --enable-libfreetype --enable-libass"
}

##
# ffmpeg
# note: pas dispo dans base ni epel
##
installFfmpeg() {
  echo "* installFfmpeg"
  cd "$SRC_PATH" || return
  if [ ! -d "ffmpeg-4.2.2" ]; then
    curl -O -L https://ffmpeg.org/releases/ffmpeg-4.2.2.tar.bz2 && \
    tar xjvf ffmpeg-4.2.2.tar.bz2 && \
    rm ffmpeg-4.2.2.tar.bz2
  fi
  cd ffmpeg-4.2.2 && \
  PATH="$BIN_PATH:$PATH" PKG_CONFIG_PATH="$BUILD_PATH/lib/pkgconfig" ./configure \
    --prefix="$BUILD_PATH" \
    --pkg-config-flags=--static \
    --extra-cflags="-I$BUILD_PATH/include" \
    --extra-ldflags="-L$BUILD_PATH/lib" \
    --extra-libs=-lpthread \
    --extra-libs=-lm \
    --bindir="$BIN_PATH" \
    ${FFMPEG_ENABLE} && \
  PATH="$BIN_PATH:$PATH" make -j "${CPU_COUNT}" && \
  make install
}

##
# à adapter (commenter/décommenter) suivant les besoins
##

echo "DEBUT compilation FFMPEG"

# Dépendances générales"
yum -y install autoconf automake bzip2 bzip2-devel cmake freetype-devel gcc gcc-c++ git libtool make mercurial pkgconfig zlib-devel

installNASM
installYasm

installLibX264
installLibX265
installLibFdkAac
installLibAss

enableLibX264
enableLibX265
enableLibFdkAac
enableLibAss

#disableFfplay
enableFfplay

installFfmpeg

echo "FIN compilation FFMPEG"
