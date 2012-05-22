#!/bin/bash
#
# This script downloads and compiles wget-warc-lua.
#

# first, try to detect gnutls or openssl
CONFIGURE_SSL_OPT=""
if builtin type -p pkg-config &>/dev/null
then
  if pkg-config gnutls
  then
    echo "Compiling wget with GnuTLS."
    CONFIGURE_SSL_OPT="--with-ssl=gnutls"
  elif pkg-config openssl
  then
    echo "Compiling wget with OpenSSL."
    CONFIGURE_SSL_OPT="--with-ssl=openssl"
  fi
fi

if builtin type -p pkg-config &>/dev/null
then
  if ! pkg-config lua && ! pkg-config lua5.1
  then
    echo "You need Lua"
    exit
  fi
fi

TARFILE=wget-lua-20120522.tar.gz
TARDIR=wget-UNKNOWN

rm -rf $TARFILE $TARDIR/

wget --no-check-certificate https://github.com/downloads/ArchiveTeam/tabblo-grab/$TARFILE
tar xzf $TARFILE
cd $TARDIR/
if ./configure $CONFIGURE_SSL_OPT --disable-nls && make
then
  cp src/wget ../wget-warc-lua
  cd ../
  echo
  echo
  echo "###################################################################"
  echo
  echo "wget-warc-lua successfully built."
  echo
  ./wget-warc-lua --help | grep -iE "gnu|warc"
  rm -rf $TARFILE $TARDIR/
else
  echo
  echo "wget-warc-lua not successfully built."
  echo
fi

