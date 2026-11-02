#!/bin/bash
# Downloads and builds the Concorde TSP solver on macOS.
#
#   Concorde source: https://github.com/matthelb/concorde (mirror of Concorde 03.12.19)
#   LP solver:       QSopt, https://www.math.uwaterloo.ca/~bico/qsopt/
#
# QSopt is only published as an x86_64 library for macOS, so on Apple Silicon
# everything is compiled for x86_64 and runs under Rosetta 2.
#
# Result: Concorde/build/concorde/TSP/concorde and Concorde/build/concorde/LINKERN/linkern
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
mkdir -p "$BUILD"
cd "$BUILD"

if [ ! -d concorde ]; then
    git clone --depth 1 https://github.com/matthelb/concorde.git
fi

mkdir -p qsopt
for f in qsopt.a qsopt.h; do
    [ -f "qsopt/$f" ] || curl -fsSL -o "qsopt/$f" "https://www.math.uwaterloo.ca/~bico/qsopt/beta/codes/mac64/$f"
done

if [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "Rosetta 2 is needed. Install it with:  softwareupdate --install-rosetta" >&2
    exit 1
fi

# Concorde is 1990s C; modern clang treats some of its idioms as errors.
CFLAGS="-O2 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion \
-Wno-incompatible-pointer-types -Wno-deprecated-non-prototype -Wno-return-type"

cd concorde
arch -x86_64 /bin/bash -c "
    set -e
    CC='clang -arch x86_64' CFLAGS='$CFLAGS' ./configure --with-qsopt='$BUILD/qsopt' --host=x86_64-apple-darwin
    make -j8
"

echo
echo "Built:"
ls -la "$BUILD/concorde/TSP/concorde" "$BUILD/concorde/LINKERN/linkern"
