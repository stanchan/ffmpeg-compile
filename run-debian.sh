#!/usr/bin/env bash

##
# Compilation FFMPEG sous Debian
#
# à exécuter en root dans un container docker
##

SRC_PATH=/root/debian/ffmpeg_sources
BUILD_PATH=/root/debian/ffmpeg_build
BIN_PATH=/root/debian/bin
FFMPEG_ENABLE="--enable-gpl --enable-nonfree"

[ ! -d "$SRC_PATH" ] && mkdir -pv "$SRC_PATH"
[ ! -d "$BUILD_PATH" ] && mkdir -pv "$BUILD_PATH"
[ ! -d "$BIN_PATH" ] && mkdir -pv "$BIN_PATH"

##
# activer ffplay
##
enableFfplay() {
  echo "* enableFfplay"
  apt-get -y install libsdl2-dev libva-dev libvdpau-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev
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
##
installNASM() {
  cd "$SRC_PATH" || return
  if [ ! -d "nasm-2.14.02" ]; then
    curl -O -L https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2
    tar xjvf nasm-2.14.02.tar.bz2
  fi
  cd nasm-2.14.02 && \
  ./autogen.sh && \
  ./configure --prefix="$BUILD_PATH" --bindir="$BIN_PATH" && \
  make && \
  make install
}

##
# Yasm
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
  make && \
  make install
}

##
# libx264
##
installLibX264() {
  echo "* installLibX264"

  # version déjà packagée par Debian
  apt-get install -y libx264-dev
  return

  # ou à partir des sources
  cd "$SRC_PATH" || return
  if [ ! -d "x264" ]; then
    git clone --depth 1 https://code.videolan.org/videolan/x264.git
  fi
  cd x264 && \
  PATH="$BIN_PATH:$PATH" ./configure --prefix="$BUILD_PATH" --bindir="$BIN_PATH" --enable-static && \
  PATH="$BIN_PATH:$PATH" make && \
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
  apt-get install -y libx265-dev libnuma-dev
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
  make && \
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
#
##
installLibAss() {
  echo "* installLibAss"
}

##
#
##
enableLibAss() {
  echo "* enableLibAss"
}

##
# ffmpeg
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
    --pkg-config-flags="--static" \
    --extra-cflags="-I$BUILD_PATH/include" \
    --extra-ldflags="-L$BUILD_PATH/lib" \
    --extra-libs="-lpthread -lm" \
    --bindir="$BIN_PATH" \
    ${FFMPEG_ENABLE} && \
  PATH="$BIN_PATH:$PATH" make && \
  make install
}

##
# diverses dépendances
##

apt-get update && apt-get install -y curl bzip2 autoconf automake g++ cmake libtool pkg-config git-core

#  ajout ?
#  build-essential \
#  libass-dev \
#  libfreetype6-dev \
#  libvorbis-dev \
#  zlib1g-dev

##
# à adapter (commenter/décommenter) suivant les besoins
##

echo "DEBUT compilation FFMPEG"

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
