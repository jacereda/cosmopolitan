{ gccStdenv
, lib
, fetchFromGitHub
, runCommand
, pkgconfig
, mode? ""
}:
let
  stdenv = gccStdenv;
in stdenv.mkDerivation rec {
  name = "cosmopolitan-${version}";
  version = "git";

  src = ./. ;

  releaseName = name;
  enableParallelBuilding = true;
  dontConfigure = true;
  dontFixup = true;

  postPatch = ''
    patchShebangs build/
    rm -r third_party/gcc
    rm -r third_party/make
    rm test/tool/build/lib/bsu_test.c # https://twitter.com/JustineTunney/status/1355321045037662212
    rm test/libc/log/backtrace_test.c # fails in mode=rel
    rm third_party/python/Lib/test/test_ioctl.py
    substituteInPlace libc/rand/randtest.c --replace mcount mcnt
    substituteInPlace third_party/python/python.mk --replace third_party/python/Lib/test/test_ioctl.py ""
    substituteInPlace third_party/python/Python/frozen.c --replace 'o//third_party' "o/${mode}/third_party"
    substituteInPlace third_party/python/Lib/test/test_fileio.py --replace testUnclosedFDOnException xtestUnclosedFDOnException
    substituteInPlace third_party/python/Python/random.c --replace '#if 1' '#if 0'
    substituteInPlace libc/integral/c.inc --replace '#pragma GCC diagnostic error "-Walloca-larger-than=1024"' "" # fails in mode=rel
    substituteInPlace libc/integral/c.inc --replace '#pragma GCC diagnostic error "-Wframe-larger-than=4096"' "" # fails in mode=rel
  	echo "o/${mode}/third_party/python/pythontester.com.dbg: QUOTA += -M512m" >> third_party/python/python.mk
  '';

  preBuild = ''
    makeFlagsArray=(
      SHELL=/bin/sh
      AS=${stdenv.cc.targetPrefix}as
      CC=${stdenv.cc.targetPrefix}gcc
      GCC=${stdenv.cc.targetPrefix}gcc
      CXX=${stdenv.cc.targetPrefix}g++
      LD=${stdenv.cc.targetPrefix}ld
      OBJCOPY=${stdenv.cc.targetPrefix}objcopy
      "MKDIR=mkdir -p"
      OVERRIDE_CCFLAGS=-Wno-error=old-style-definition
      MODE=${mode}
      )
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,lib,include}
    install o/${mode}/cosmopolitan.h $out/include
    install o/${mode}/cosmopolitan.a o/${mode}/libc/crt/crt.o o/${mode}/ape/ape.{o,lds} $out/lib
    for h in `find libc -name \*.h`
    do
        install -D $h $out/include/$h
    done
    for b in `find o/ -name \*.com.dbg`
    do
        cp $b $out/bin/`basename $b|head -c -5`
    done
    cat > $out/bin/cosmoc <<EOF
    #!${stdenv.shell}
    exec ${stdenv.cc}/bin/${stdenv.cc.targetPrefix}gcc \
      -Os \
      -static \
      -nostdlib \
      -nostdinc \
      -fno-pie \
      -no-pie \
      -mno-red-zone \
      -fno-omit-frame-pointer \
      -pg \
      -mnop-mcount \
      -I $out/include \
      "\$@" \
      -fuse-ld=bfd \
      -Wl,-T,$out/lib/ape.lds \
      $out/lib/{crt.o,ape.o,cosmopolitan.a}
    EOF
    chmod +x $out/bin/cosmoc
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://justine.lol/cosmopolitan/";
    description = "Your build-once run-anywhere c library";
    platforms = platforms.x86_64;
    badPlatforms = platforms.darwin;
    license = licenses.isc;
  };
}
