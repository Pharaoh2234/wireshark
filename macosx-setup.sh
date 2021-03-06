#!/bin/sh
# Setup development environment on Mac OS X (tested with 10.6.8 and Xcode 3.2.6)
#
# $Id$
#
# Trying to follow "Building Wireshark on SnowLeopard"
# given by Michael Tuexen at
# http://nplab.fh-muenster.de/groups/wiki/wiki/fb7a4/Building_Wireshark_on_SnowLeopard.html
#

MACOSX_VERSION=`uname -r | sed 's/\([0-9]*\).*/\1/'`

# To set up a GTK3 environment
# GTK3=1
# To build cmake
# CMAKE=1
#
# Versions to download and install.
#
# The following libraries are required.
#
GETTEXT_VERSION=0.18.1.1
GLIB_VERSION=2.32.3
#
# pkg-config 0.26 appears to have broken the "we have our own GLib"
# stuff, even if you explicitly set GLIB_CFLAGS and GLIB_LIBS.
#
PKG_CONFIG_VERSION=0.26
ATK_VERSION=2.4.0
PANGO_VERSION=1.30.0
PNG_VERSION=1.5.12
PIXMAN_VERSION=0.26.0
CAIRO_VERSION=1.12.2
GDK_PIXBUF_VERSION=2.26.1
if [ -z "$GTK3" ]; then
  GTK_VERSION=2.24.10
else
  GTK_VERSION=3.5.2
fi

#
# Some package need xz to unpack their current source.
# xz is not available on OSX (Snow Leopard).
#
XZ_VERSION=5.0.3

# In case we want to build with cmake
CMAKE_VERSION=2.8.8

#
# The following libraries are optional.
# Comment them out if you don't want them, but note that some of
# the optional libraries are required by other optional libraries.
#
LIBSMI_VERSION=0.4.8
#
# libgpg-error is required for libgcrypt.
#
LIBGPG_ERROR_VERSION=1.10
#
# libgcrypt is required for GnuTLS.
# XXX - the link for "Libgcrypt source code" at
# http://www.gnupg.org/download/#libgcrypt is for 1.5.0, and is a bzip2
# file, but http://directory.fsf.org/project/libgcrypt/ lists only
# 1.4.6.
#
LIBGCRYPT_VERSION=1.5.0
GNUTLS_VERSION=2.12.19
# Stay with Lua 5.1 when updating until the code has been changed
# to support 5.2
LUA_VERSION=5.1.5
PORTAUDIO_VERSION=pa_stable_v19_20111121
#
# XXX - they appear to have an unversioned gzipped tarball for the
# current version; should we just download that, with some other
# way of specifying whether to download the GeoIP API?
#
GEOIP_VERSION=1.4.8

#
# You need Xcode installed to get the compilers.
#
if [ ! -x /usr/bin/xcodebuild ]; then
	echo "Please install Xcode first (should be available on DVD or from http://developer.apple.com/xcode/index.php)."
	exit 1
fi

#
# You also need the X11 SDK; with at least some versions of OS X and
# Xcode, that is, I think, an optional install.  (Or it might be
# installed with X11, but I think *that* is an optional install on
# at least some versions of OS X.)
#
if [ ! -d /usr/X11/include ]; then
	echo "Please install X11 and the X11 SDK first."
	exit 1
fi

#
# Do we have permission to write in /usr/local?
#
# If so, assume we have permission to write in its subdirectories.
# (If that's not the case, this test needs to check the subdirectories
# as well.)
#
# If not, do "make install" with sudo.
#
if [ -w /usr/local ]
then
	DO_MAKE_INSTALL="make install"
else
	DO_MAKE_INSTALL="sudo make install"
fi

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/X11/lib/pkgconfig

#
# Do all the downloads and untarring in a subdirectory, so all that
# stuff can be removed once we've installed the support libraries.
#
if [ ! -d macosx-support-libs ]
then
	mkdir macosx-support-libs || exit 1
fi
cd macosx-support-libs

# Start with xz: It is the sole download format of glib later than 2.31.2
#
echo "Downloading, building, and installing xz:"
curl -O http://tukaani.org/xz/xz-$XZ_VERSION.tar.bz2 || exit 1
tar xf xz-$XZ_VERSION.tar.bz2 || exit 1
cd xz-$XZ_VERSION
CFLAGS="-D_FORTIFY_SOURCE=0" ./configure || exit 1
make -j 3 || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

if [ -n "$CMAKE" ]; then
  echo "Downloading, building, and installing CMAKE:"
  cmake_dir=`expr $CMAKE_VERSION : '\([0-9][0-9]*\.[0-9][0-9]*\).*'`
  curl -O http://www.cmake.org/files/v$cmake_dir/cmake-$CMAKE_VERSION.tar.gz || exit 1
  gzcat cmake-$CMAKE_VERSION.tar.gz | tar xf - || exit 1
  cd cmake-$CMAKE_VERSION
  ./bootstrap || exit 1
  make -j 3 || exit 1
  $DO_MAKE_INSTALL || exit 1
  cd ..
fi

#
# Start with GNU gettext; GLib requires it, and OS X doesn't have it
# or a BSD-licensed replacement.
#
# At least on Lion with Xcode 4, _FORTIFY_SOURCE gets defined as 2
# by default, which causes, for example, stpncpy to be defined as
# a hairy macro that collides with the GNU gettext configure script's
# attempts to workaround AIX's lack of a declaration for stpncpy,
# with the result being a huge train wreck.  Define _FORTIFY_SOURCE
# as 0 in an attempt to keep the trains on separate tracks.
#
echo "Downloading, building, and installing GNU gettext:"
curl -O http://ftp.gnu.org/pub/gnu/gettext/gettext-$GETTEXT_VERSION.tar.gz || exit 1
tar xf gettext-$GETTEXT_VERSION.tar.gz || exit 1
cd gettext-$GETTEXT_VERSION
CFLAGS="-D_FORTIFY_SOURCE=0" ./configure || exit 1
make -j 3 || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

echo "Downloading, building, and installing GLib:"
glib_dir=`expr $GLIB_VERSION : '\([0-9][0-9]*\.[0-9][0-9]*\).*'`
curl -L -O http://ftp.gnome.org/pub/gnome/sources/glib/$glib_dir/glib-$GLIB_VERSION.tar.xz || exit 1
xzcat glib-$GLIB_VERSION.tar.xz | tar xf - || exit 1
cd glib-$GLIB_VERSION
#
# OS X ships with libffi, but doesn't provide its pkg-config file;
# explicitly specify LIBFFI_CFLAGS and LIBFFI_LIBS, so the configure
# script doesn't try to use pkg-config to get the appropriate
# CFLAGS and LIBS.
#
# And, what's worse, at least with the version of Xcode that comes
# with Leopard, /usr/include/ffi/fficonfig.h doesn't define MACOSX,
# which causes the build of GLib to fail.  If we don't find
# "#define.*MACOSX" in /usr/include/ffi/fficonfig.h, explictly
# define it.
#
if grep -qs '#define.*MACOSX' /usr/include/ffi/fficonfig.h
then
	# It's defined, nothing to do
	LIBFFI_CFLAGS="-I/usr/include/ffi" LIBFFI_LIBS="-lffi" ./configure || exit 1
else
	CFLAGS="-DMACOSX" LIBFFI_CFLAGS="-I/usr/include/ffi" LIBFFI_LIBS="-lffi" ./configure || exit 1
fi
make -j 3 || exit 1
# Apply patch: we depend on libffi, but pkg-config doesn't get told.
patch -p0 <../../macosx-support-lib-patches/glib-pkgconfig.patch || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

echo "Downloading, building, and installing pkg-config:"
curl -O http://pkgconfig.freedesktop.org/releases/pkg-config-$PKG_CONFIG_VERSION.tar.gz || exit 1
tar xf pkg-config-$PKG_CONFIG_VERSION.tar.gz || exit 1
cd pkg-config-$PKG_CONFIG_VERSION
# Avoid another pkgconfig call
GLIB_CFLAGS="-I/usr/local/include/glib-2.0 -I/usr/local/lib/glib-2.0/include" GLIB_LIBS="-L/usr/local/lib -lglib-2.0 -lintl" ./configure || exit 1
# ./configure || exit 1
make -j 3 || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

#
# Now we have reached a point where we can build everything but
# the GUI (Wireshark).
#
# Cairo is part of Mac OS X 10.6 and 10.7.
# The *headers* are supplied by 10.5, but the *libraries* aren't, so
# we have to build it on 10.5.
# GTK+ 3 requires a newer Cairo build than the one that comes with
# 10.6, so we build Cairo if we are using GTK+ 3.
# In 10.6 and 10.7, it's an X11 library; if we build with "native" GTK+
# rather than X11 GTK+, we might have to build and install Cairo.
#
if [[ -n "$GTK3" || $MACOSX_VERSION = "9" ]]; then
  #
  # Requirements for Cairo first
  #
  echo "Downloading, building, and installing libpng:"
  curl -O ftp://ftp.simplesystems.org/pub/libpng/png/src/libpng-$PNG_VERSION.tar.xz
  xzcat libpng-$PNG_VERSION.tar.xz | tar xf - || exit 1
  cd libpng-$PNG_VERSION
  ./configure || exit 1
  make -j 3 || exit 1
  $DO_MAKE_INSTALL || exit 1
  cd ..

  echo "Downloading, building, and installing pixman:"
  curl -O http://www.cairographics.org/releases/pixman-$PIXMAN_VERSION.tar.gz
  gzcat pixman-$PIXMAN_VERSION.tar.gz | tar xf - || exit 1
  cd pixman-$PIXMAN_VERSION
  ./configure || exit 1
  make -j 3 || exit 1
  $DO_MAKE_INSTALL || exit 1
  cd ..

  #
  # And now Cairo itself.
  #
  echo "Downloading, building, and installing Cairo:"
  curl -O http://cairographics.org/releases/cairo-$CAIRO_VERSION.tar.xz || exit 1
  xzcat cairo-$CAIRO_VERSION.tar.xz | tar xf - || exit 1
  cd cairo-$CAIRO_VERSION
  #./configure --enable-quartz=no || exit 1
  # Maybe follow http://cairographics.org/end_to_end_build_for_mac_os_x/
  ./configure --enable-quartz=yes || exit 1
  make -j 3 || exit 1
  $DO_MAKE_INSTALL || exit 1
  cd ..
fi

echo "Downloading, building, and installing ATK:"
atk_dir=`expr $ATK_VERSION : '\([0-9][0-9]*\.[0-9][0-9]*\).*'`
curl -O http://ftp.gnome.org/pub/gnome/sources/atk/$atk_dir/atk-$ATK_VERSION.tar.xz || exit 1
xzcat atk-$ATK_VERSION.tar.xz | tar xf - || exit 1
cd atk-$ATK_VERSION
./configure || exit 1
make -j 3 || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

echo "Downloading, building, and installing Pango:"
pango_dir=`expr $PANGO_VERSION : '\([0-9][0-9]*\.[0-9][0-9]*\).*'`
curl -L -O http://ftp.gnome.org/pub/gnome/sources/pango/$pango_dir/pango-$PANGO_VERSION.tar.xz
xzcat pango-$PANGO_VERSION.tar.xz | tar xf - || exit 1
cd pango-$PANGO_VERSION
./configure || exit 1
make -j 3 || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

echo "Downloading, building, and installing gdk-pixbuf:"
gdk_pixbuf_dir=`expr $GDK_PIXBUF_VERSION : '\([0-9][0-9]*\.[0-9][0-9]*\).*'`
curl -L -O http://ftp.gnome.org/pub/gnome/sources/gdk-pixbuf/$gdk_pixbuf_dir/gdk-pixbuf-$GDK_PIXBUF_VERSION.tar.xz || exit 1
xzcat gdk-pixbuf-$GDK_PIXBUF_VERSION.tar.xz | tar xf - || exit 1
cd gdk-pixbuf-$GDK_PIXBUF_VERSION
./configure --without-libtiff --without-libjpeg || exit 1
make -j 3 || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

echo "Downloading, building, and installing GTK+:"
gtk_dir=`expr $GTK_VERSION : '\([0-9][0-9]*\.[0-9][0-9]*\).*'`
curl -L -O http://ftp.gnome.org/pub/gnome/sources/gtk+/$gtk_dir/gtk+-$GTK_VERSION.tar.xz
xzcat gtk+-$GTK_VERSION.tar.xz | tar xf - || exit 1
cd gtk+-$GTK_VERSION
#
# GTK+ 2.24.10, at least, doesn't build on Mountain Lion with the CUPS
# printing backend - either the CUPS API changed incompatibly or the
# backend was depending on non-API implementation details.
#
# Configure it out for now.
#
if [ $MACOSX_VERSION -ge "12" ]
then
	./configure --disable-cups || exit 1
else
	./configure || exit 1
fi
make -j 3 || exit 1
$DO_MAKE_INSTALL || exit 1
cd ..

#
# Now we have reached a point where we can build everything including
# the GUI (Wireshark), but not with any optional features such as
# SNMP OID resolution, some forms of decryption, Lua scripting, playback
# of audio, or GeoIP mapping of IP addresses.
#
# We now conditionally download optional libraries to support them;
# the default is to download them all.
#

if [ ! -z $LIBSMI_VERSION ]
then
	echo "Downloading, building, and installing libsmi:"
	curl -L -O ftp://ftp.ibr.cs.tu-bs.de/pub/local/libsmi/libsmi-$LIBSMI_VERSION.tar.gz || exit 1
	tar xf libsmi-$LIBSMI_VERSION.tar.gz || exit 1
	cd libsmi-$LIBSMI_VERSION
	./configure || exit 1
	make -j 3 || exit 1
	$DO_MAKE_INSTALL || exit 1
	cd ..
fi

if [ ! -z $LIBGPG_ERROR_VERSION ]
then
	echo "Downloading, building, and installing libgpg-error:"
	curl -L -O ftp://ftp.gnupg.org/gcrypt/libgpg-error/libgpg-error-$LIBGPG_ERROR_VERSION.tar.bz2 || exit 1
	bzcat libgpg-error-$LIBGPG_ERROR_VERSION.tar.bz2 | tar xf - || exit 1
	cd libgpg-error-$LIBGPG_ERROR_VERSION
	./configure || exit 1
	make -j 3 || exit 1
	$DO_MAKE_INSTALL || exit 1
	cd ..
fi

if [ ! -z $LIBGCRYPT_VERSION ]
then
	#
	# libgpg-error is required for libgcrypt.
	#
	if [ -z $LIBGPG_ERROR_VERSION ]
	then
		echo "libgcrypt requires libgpg-error, but you didn't install libgpg-error." 1>&2
		exit 1
	fi

	echo "Downloading, building, and installing libgcrypt:"
	curl -L -O ftp://ftp.gnupg.org/gcrypt/libgcrypt/libgcrypt-$LIBGCRYPT_VERSION.tar.gz || exit 1
	tar xf libgcrypt-$LIBGCRYPT_VERSION.tar.gz || exit 1
	cd libgcrypt-$LIBGCRYPT_VERSION
	#
	# The assembler language code is not compatible with the OS X
	# x86 assembler (or is it an x86-64 vs. x86-32 issue?).
	#
	./configure --disable-asm || exit 1
	make -j 3 || exit 1
	$DO_MAKE_INSTALL || exit 1
	cd ..
fi

if [ ! -z $GNUTLS_VERSION ]
then
	#
	# GnuTLS requires libgcrypt (or nettle, in newer versions).
	#
	if [ -z $LIBGCRYPT_VERSION ]
	then
		echo "GnuTLS requires libgcrypt, but you didn't install libgcrypt" 1>&2
		exit 1
	fi

	echo "Downloading, building, and installing GnuTLS:"
	curl -L -O http://ftp.gnu.org/gnu/gnutls/gnutls-$GNUTLS_VERSION.tar.bz2 || exit 1
	bzcat gnutls-$GNUTLS_VERSION.tar.bz2 | tar xf - || exit 1
	cd gnutls-$GNUTLS_VERSION
	#
	# Use libgcrypt, not nettle.
	# XXX - is there some reason to prefer nettle?  Or does
	# Wireshark directly use libgcrypt routines?
	#
	./configure --with-libgcrypt --without-p11-kit || exit 1
	make -j 3 || exit 1
	#
	# The pkgconfig file for GnuTLS says "requires zlib", but OS X,
	# while it supplies zlib, doesn't supply a pkgconfig file for
	# it.
	#
	# Patch the GnuTLS pkgconfig file not to require zlib.
	# (If the capabilities of GnuTLS that Wireshark uses don't
	# depend on building GnuTLS with zlib, an alternative would be
	# to configure it not to use zlib.)
	#
	patch -p0 lib/gnutls.pc.in <../../macosx-support-lib-patches/gnutls-pkgconfig.patch || exit 1
	$DO_MAKE_INSTALL || exit 1
	cd ..
fi

if [ ! -z $LUA_VERSION ]
then
	echo "Downloading, building, and installing Lua:"
	curl -L -O http://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz || exit 1
	tar xf lua-$LUA_VERSION.tar.gz || exit 1
	cd lua-$LUA_VERSION
	make -j 3 macosx || exit 1
	$DO_MAKE_INSTALL || exit 1
	cd ..
fi

if [ ! -z $PORTAUDIO_VERSION ]
then
	echo "Downloading, building, and installing PortAudio:"
	curl -L -O http://www.portaudio.com/archives/$PORTAUDIO_VERSION.tgz || exit 1
	tar xf $PORTAUDIO_VERSION.tgz || exit 1
	cd portaudio
	#
	# Un-comment an include that's required on Lion.
	#
	patch -p0 include/pa_mac_core.h <../../macosx-support-lib-patches/portaudio-pa_mac_core.h.patch
	#
	# Disable fat builds - the configure script doesn't work right
	# with Xcode 4 if you leave them enabled, and we don't build
	# any other libraries fat (GLib, for example, would be very
	# hard to build fat), so there's no advantage to having PortAudio
	# built fat.
	#
	# Set the minimum OS X version to 10.4, to suppress some
	# deprecation warnings.
	#
	CFLAGS="-mmacosx-version-min=10.4" ./configure --disable-mac-universal || exit 1
	make -j 3 || exit 1
	$DO_MAKE_INSTALL || exit 1
	cd ..
fi

if [ ! -z $GEOIP_VERSION ]
then
	echo "Downloading, building, and installing GeoIP API:"
	curl -L -O http://geolite.maxmind.com/download/geoip/api/c/GeoIP-$GEOIP_VERSION.tar.gz || exit 1
	tar xf GeoIP-$GEOIP_VERSION.tar.gz || exit 1
	cd GeoIP-$GEOIP_VERSION
	./configure || exit 1
	#
	# Grr.  Their man pages "helpfully" have an ISO 8859-1
	# copyright symbol in the copyright notice, but OS X's
	# default character encoding is UTF-8.  sed on Mountain
	# Lion barfs at the "illegal character sequence" represented
	# by an ISO 8859-1 copyright symbol, as it's not a valid
	# UTF-8 sequence.
	#
	# iconv the relevant man pages into UTF-8.
	#
	for i in geoipupdate.1.in geoiplookup6.1.in geoiplookup.1.in
	do
		iconv -f iso8859-1 -t utf-8 man/"$i" >man/"$i".tmp &&
		    mv man/"$i".tmp man/"$i"
	done
	make -j 3 || exit 1
	$DO_MAKE_INSTALL || exit 1
	cd ..
fi

echo ""

echo "You are now prepared to build Wireshark. To do so do:"
echo "export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/X11/lib/pkgconfig"
echo ""
if [ -n "$CMAKE" ]; then
  echo "mkdir build; cd build"
  echo "cmake .."
  echo
  echo "or"
  echo
fi
echo "./autogen.sh"
echo "mkdir build; cd build"
echo "../configure"
echo ""
echo "make -j 3"
echo "make install"

echo ""

echo "Make sure you are allowed capture access to the network devices"
echo "See: http://wiki.wireshark.org/CaptureSetup/CapturePrivileges"

echo ""

exit 0
