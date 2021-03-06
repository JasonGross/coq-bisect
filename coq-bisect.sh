#!/bin/bash

SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
MYDIR="$(dirname "$SCRIPT")"
COQ_DIR="$MYDIR/coq"

# exit immediately and abort the bisect if killed
trap "exit 128" SIGHUP SIGINT SIGTERM

function do_sleep {
    sleep 1
    true
}

cd "$MYDIR"

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
    echo "       or have an example.v file, and the value of \$FILE ($FILE) must be an existing file."
    echo "       This file is used as the test file."
    exit 128
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
    git clean -xfd >/dev/null
    git reset --hard >/dev/null
    git checkout origin/trunk
    if [ -z "$BAD" ]
    then
	echo "WARNING: You can set the BAD environment variable, or have a BAD= line in ./environ."
	echo "         The BAD variable is used to name the first bad commit"
	BADGOOD=""
    elif [ -z "$GOOD" ]
    then
	echo "WARNING: You can set the GOOD environment variable, or have a GOOD= line in ./environ."
	echo "         The GOOD variable is used to name the first good commit"
	BADGOOD="$BAD"
    else
	BADGOOD="$BAD $GOOD"
    fi
    # git bisect start [--no-checkout] [<bad> [<good>...]] [--] [<paths>...]
    git bisect start $BADGOOD
    git bisect run "$SCRIPT" "$@" 2>&1 | tee coq-bisect.log
    git reset --hard
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
for arg in "-nodoc"; do
    if [ ! -z "$(./configure -h 2>&1 | grep -- "$arg")" ]; then
	ARGS="$ARGS $arg"
    fi
done
for arg in "-coqide" "-with-doc"; do
    if [ ! -z "$(./configure -h 2>&1 | grep -- "$arg")" ]; then
	ARGS="$ARGS $arg no"
    fi
done
if [ ! -z "$(./configure -h 2>&1 | grep -- -camlp5dir)" ]; then
    if which ocamlfind >/dev/null 2>&1; then
        if ocamlfind query camlp5 >/dev/null 2>&1; then
            ARGS="$ARGS -camlp5dir $(ocamlfind query camlp5 | sed s'/ /\\ /g')"
        fi
    fi
fi
if [ "$1" == "--no-build" ]; then
    shift
else
    git clean -xfd >/dev/null
    echo "Removing make check from configure"
    if [ "$(grep -c '"$MAKEVERSIONMAJOR" -eq 3 -a "$MAKEVERSIONMINOR" -ge 81' configure 2>/dev/null)" -eq 1 ]; then
	sed s'/".MAKEVERSIONMAJOR" -eq 3 -a ".MAKEVERSIONMINOR" -ge 81/true/g' -i configure
    fi
    echo "./configure $ARGS"
    ./configure $ARGS
    if [ -z "$MAKE_TARGET" ]; then
	MAKE_TARGET=coqlight
	echo "Defaulting MAKE_TARGET to $MAKE_TARGET"
    fi
    echo "Fixing unterminated string literal"
    if [ ! -z "$(git grep --name-only '{w|' "*.ml")" ]; then
        git grep --name-only '{w|' "*.ml" | xargs sed s'/{w|/{ w |/g' -i
    fi
    make $MAKE_TARGET "$@" || (git reset --hard; exit 125)
    git reset --hard
fi
ls ./bin

if [ -z "$COQC_ARGS" ]; then
    COQC_ARGS="-nois -boot"
    echo "Defaulting COQC_ARGS to $COQC_ARGS"
fi

if [ -z "$COQTOP_ARGS" ]; then
    COQTOP_ARGS="${COQC_ARGS}"
    echo "Defaulting COQTOP_ARGS to $COQTOP_ARGS"
fi

if [ -z "$TIMEOUT" ]; then
    TIMEOUT=30
    echo "Defaulting TIMEOUT to $TIMEOUT"
fi

rm -f "${FILE%.v}.vo"

COQC="./bin/coqc"
if [ ! -f "$COQC" ]; then
    if [ -f "./bin/coqc.opt" ]; then
	COQC="./bin/coqc.opt"
    fi
fi

COQTOP="./bin/coqtop"
if [ ! -f "$COQTOP" ]; then
    if [ -f "./bin/coqtop.opt" ]; then
	COQTOP="./bin/coqtop.opt"
    fi
fi

if [ -z "$EMACS" ]; then
    echo "$ timeout \"$TIMEOUT\" $COQC $COQC_ARGS \"${FILE%.v}\" 2>&1"
    OUTPUT="$(timeout "$TIMEOUT" $COQC $COQC_ARGS "${FILE%.v}" 2>&1)"
    ERR=$?
else
    echo "$ cat \"${FILE}\" | timeout \"$TIMEOUT\" $COQC $COQC_ARGS -emacs 2>&1"
    OUTPUT="$(cat "${FILE}" | timeout "$TIMEOUT" $COQTOP $COQTOP_ARGS -emacs 2>&1)"
    ERR=$?
fi
ls "${FILE%.v}"*
echo "$OUTPUT"
echo "$ERR"
#echo "$FILE"
rm -f "${FILE%.v}.vo" "${FILE%.v}.glob" "N${FILE%.v}.o" "N${FILE%.v}.native" "N${FILE%.v}.cmi" "N${FILE%.v}.cmxs" "N${FILE%.v}.cmx" \
    ".coq-native/N${FILE%.v}.o" ".coq-native/N${FILE%.v}.native" ".coq-native/N${FILE%.v}.cmi" ".coq-native/N${FILE%.v}.cmxs" ".coq-native/N${FILE%.v}.cmx"

if [ ! -z "$(echo "$OUTPUT" | grep -o "$ERR_MESSAGE")" ]; then
    if [ -z "$SWAP" ]; then
	echo 'exit 1'
	do_sleep
	exit 1 # bad
    else
	echo 'exit 0'
	do_sleep
	exit 0 # bad, but we tell git bisect it's good because we're swapped
    fi
elif [ $ERR = 0 ]; then
    if [ -z "$SWAP" ]; then
	echo 'exit 0'
	do_sleep
	exit 0 # good
    else
	echo 'exit 1'
	do_sleep
	exit 1 # good, but we tell git bisect it's bad, because we're swapped
    fi
else
    echo 'exit 125'
    do_sleep
    exit 125 # failed for other reason
fi
