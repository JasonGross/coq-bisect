#!/bin/bash

SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
MYDIR="$(dirname "$SCRIPT")"
COQ_DIR="$MYDIR/coq"

# exit immediately and abort the bisect if killed
trap "exit 128" SIGHUP SIGINT SIGTERM

if [ -f "$MYDIR/environ" ]
then
    chmod +x "$MYDIR/environ"
    . "$MYDIR/environ"
fi

if [ ! -z "$FILE" ]
then
    FILE="$(readlink -f "$FILE")"
else
    FILE="$MYDIR/example.v"
fi

if [ ! -f "$FILE" ]
then
    echo "ERROR: You must set the FILE environment variable, have an FILE= line in ./environ,"
    echo "       or have an example.v file, and the value of \$FILE must be an existing file."
    echo "       This file is used as the test file."
    exit 1
fi

if [ -z "$ERR_MESSAGE" ]
then
    echo "ERROR: You must set the ERR_MESSAGE environment variable, or have an ERR_MESSAGE= line in ./environ."
    echo "       The ERR_MESSAGE variable should be a substring of the relevant error message."
fi

if [ "$1" = "--init" ]
then
    shift
    cd "$COQ_DIR"
    PS4='$ '
    set -x
    git remote update
    git clean -xfd
    git checkout origin/trunk
    if [ -z "$BAD" ]
    then
	echo "WARNING: You can set the BAD environment variable, or have a BAD= line in ./environ."
	echo "         The BAD variable is used to name the first bad commit"
	BADGOOD=""
    elif [ -z "$GOOD" ]
    then
	echo "WARNING: You can set the GOOD environment variable, or have a GOOD= line in ./environ."
	echo "         The GOOD variable is used to name the first bad commit"
	BADGOOD="$BAD"
    else
	BADGOOD="$BAD $GOOD"
    fi
    # git bisect start [--no-checkout] [<bad> [<good>...]] [--] [<paths>...]
    git bisect start $BADGOOD
    git bisect run "$SCRIPT" "$@"
    exit 128 # if git bisect run gets --init, abort immediately
fi

cd "$COQ_DIR"

ARGS="-local"

if [ -z "$CONFIGURE_ARGS" ]; then
    CONFIGURE_ARGS="-nodoc -no-native-compiler"
    echo "Defaulting CONFIGURE_ARGS to $CONFIGURE_ARGS"
fi

for arg in $CONFIGURE_ARGS; do
    if [ ! -z "$(./configure -h 2>&1 | grep -- "$arg")" ]; then
	ARGS="$ARGS $arg"
    fi
done
for arg in "-coqide" "-with-doc"; do
    if [ ! -z "$(./configure -h 2>&1 | grep -- "$arg")" ]; then
	ARGS="$ARGS $arg no"
    fi
done
if [ "$1" == "--no-build" ]; then
    shift
else
    git clean -xfd 2>&1 >/dev/null
    echo "./configure $ARGS"
    ./configure $ARGS
    if [ -z "$MAKE_TARGET" ]; then
	MAKE_TARGET=coqlight
	echo "Defaulting MAKE_TARGET to $MAKE_TARGET"
    fi
    make $MAKE_TARGET "$@" || exit 125
fi
ls ./bin

if [ -z "$COQTOP_ARGS" ]; then
    COQTOP_ARGS="-nois -boot"
    echo "Defaulting COQTOP_ARGS to $COQTOP_ARGS"
fi

if [ -z "$TIMEOUT" ]; then
    TIMEOUT=30
    echo "Defaulting TIMEOUT to $TIMEOUT"
fi

rm -f "${FILE%.v}.vo"
OUTPUT="$(timeout "$TIMEOUT" ./bin/coqtop $COQTOP_ARGS -compile "${FILE%.v}" 2>&1)"
ls *"${FILE%.v}"*
ERR=$?
echo "$OUTPUT"
echo "$ERR"
#echo "$FILE"
rm -f "${FILE%.v}.vo" "${FILE%.v}.glob" "N${FILE%.v}.o" "N${FILE%.v}.native" "N${FILE%.v}.cmi" "N${FILE%.v}.cmxs" "N${FILE%.v}.cmx" \
    ".coq-native/N${FILE%.v}.o" ".coq-native/N${FILE%.v}.native" ".coq-native/N${FILE%.v}.cmi" ".coq-native/N${FILE%.v}.cmxs" ".coq-native/N${FILE%.v}.cmx"

if [ ! -z "$(echo "$OUTPUT" | grep -o "$ERR_MESSAGE")" ]; then
    if [ -z "$SWAP" ]; then
	echo 'exit 1'
	exit 1 # bad
    else
	echo 'exit 0'
	exit 0 # bad, but we tell git bisect it's good because we're swapped
    fi
elif [ $ERR = 0 ]; then
    if [ -z "$SWAP" ]; then
	echo 'exit 0'
	exit 0 # good
    else
	echo 'exit 1'
	exit 1 # good, but we tell git bisect it's bad, because we're swapped
    fi
else
    echo 'exit 125'
    exit 125 # failed for other reason
fi
