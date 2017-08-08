FROM lsiobase/alpine:3.6
MAINTAINER sparklyballs

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"

# package versions
ARG FFMPEG_VER="3.3.3"
ARG MONO_VER="5.4.0.56"
ARG REFERENCEASSEMBLIES_COMMIT="874cf94eeaf35aa267878f9983b280a00e7bed19"

# copy patches
COPY patches/ /tmp/patches/

# install build packages
RUN \
 apk add --no-cache --virtual=build-dependencies \
	alsa-lib-dev \
	autoconf \
	automake \
	binutils \
	bzip2-dev \
	cmake \
	curl \
	file \
	g++ \
	gcc \
	gettext \
	git \
	gnutls-dev \
	jpeg-dev \
	lame-dev \
	lcms2-dev \
	libass-dev \
	libtheora-dev \
	libtool \
	libva-dev \
	libvorbis-dev \
	libvpx-dev \
	libwebp-dev \
	libxfixes-dev \
	make \
	openjpeg-dev \
	opus-dev \
	paxmark \
	perl \
	rtmpdump-dev \
	sdl-dev \
	soxr-dev \
	speex-dev \
	tar \
	v4l-utils-dev \
	x264-dev \
	x265-dev \
	xvidcore-dev \
	yasm \
	zlib-dev && \

# install runtime packages
 apk add --no-cache \
	alsa-lib \
	fontconfig \
	freetype \
	fribidi \
	imagemagick \
	libgomp \
	librtmp \
	libtheora \
	libva \
	libva-intel-driver \
	libvorbis \
	libvpx \
	libwebp \
	libxcb \
	openjpeg \
	opus \
	python \
	soxr \
	speex \
	sqlite \
	unzip \
	v4l-utils-libs \
	x264 \
	x264-libs \
	x265 \
	xvidcore \
	zlib && \
 apk add --no-cache \
	--repository http://nl.alpinelinux.org/alpine/edge/testing \
	libgdiplus && \

# compile mono
 mkdir -p \
	/tmp/mono-src && \
 curl -o \
 /tmp/mono.tar.bz2 -L \
	"https://download.mono-project.com/sources/mono/mono-${MONO_VER}.tar.bz2" && \
 tar xf \
 /tmp/mono.tar.bz2 -C \
	/tmp/mono-src --strip-components=1 && \
 cd /tmp/mono-src && \
 sed -i \
	's|$mono_libdir/||g' \
	/tmp/mono-src/data/config.in && \
 sed -i \
	'/exec "/ i\paxmark mr "$(readlink -f "$MONO_EXECUTABLE")"' \
	/tmp/mono-src/runtime/mono-wrapper.in && \
 export CFLAGS="$CFLAGS -Os -fno-strict-aliasing" && \
 ./configure \
	--disable-boehm \
	--disable-libraries \
	--infodir=/opt/mono/share/info \
	--localstatedir=/var \
	--mandir=/opt/mono/share/man \
	--prefix=/opt/mono \
	--without-mcs-docs && \
 make && \
 make install && \
 find /opt/mono -name "*.so*" -exec strip --strip-unneeded {} \; && \
 strip /opt/mono/bin/mono || true && \

# install emby
 mkdir -p \
	/usr/lib/emby && \
 EMBY_VER=$(curl -sX GET "https://api.github.com/repos/mediaBrowser/Emby/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]') && \
 curl -o \
 /tmp/emby.zip -L \
	"https://github.com/MediaBrowser/Emby/releases/download/$EMBY_VER/Emby.Mono.zip" && \
 unzip -q /tmp/emby.zip -d /usr/lib/emby && \
 libMagicWand=$(find / -iname "libMagickWand-*.*.so.0" -exec basename \{} \;) && \
 libSqlite=$(find / -iname "libsqlite*.so.0" -exec basename \{} \;) && \
 IMAGEMAGIC_DLL_CONFIG=$(find /usr/lib/emby -iname "*ImageMagick*.dll.config") && \
 SQLITE_DLL_CONFIG=$(find /usr/lib/emby -iname "*sqlite3.dll.config") && \
 sed -i \
	s/libMagickWand-6.Q8.so/$libMagicWand/g \
	$IMAGEMAGIC_DLL_CONFIG && \
 sed -i \
	s/libsqlite3.so/$libSqlite/g \
	$SQLITE_DLL_CONFIG && \

# compile ffmpeg
 mkdir -p \
	/tmp/ffmpeg-src && \
 curl -o \
 /tmp/ffmpeg.tar.bz2 -L \
	"http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VER}.tar.bz2" && \
 tar xf \
 /tmp/ffmpeg.tar.bz2 -C \
	/tmp/ffmpeg-src --strip-components=1 && \
 cd /tmp/ffmpeg-src && \
 for i in /tmp/patches/ffmpeg/*.patch; do patch -p1 -i $i; done && \
 ./configure \
	--disable-debug \
	--disable-ffplay \
	--disable-indev=sndio \
	--disable-outdev=sndio \
	--disable-static \
	--disable-stripping \
	--enable-fontconfig \
	--enable-gpl \
	--enable-gray \
	--enable-libfreetype \
	--enable-libfribidi \
	--enable-libopenjpeg \
	--enable-libopus \
	--enable-librtmp \
	--enable-libsoxr \
	--enable-libspeex \
	--enable-libtheora \
	--enable-libv4l2 \
	--enable-libvorbis \
	--enable-libvpx \
	--enable-libwebp \
	--enable-libx264 \
	--enable-libx265 \
	--enable-libxvid \
	--enable-shared \
	--enable-vaapi \
	--enable-version3 \
	--prefix=/usr && \
 make && \
 make install && \

# cleanup
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/tmp/* \
	/opt/mono/lib/*.la \
	/opt/mono/lib/libMonoSupportW.* \
	/opt/mono/lib/mono/*/Mono.Security.Win32* \
	/opt/mono/lib/mono/xbuild-frameworks/.NETPortable/v4.*

# add local files
COPY root/ /

# ports and volumes
# EXPOSE
VOLUME /config
