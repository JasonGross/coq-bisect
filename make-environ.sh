#!/bin/sh

cat > environ <<EOF
FILE=example.v
ERR_MESSAGE=Error
BAD=trunk
GOOD=v8.4
CONFIGURE_ARGS=-nodoc -no-native-compiler
MAKE_TARGET=coqlight
COQTOP_ARGS=-nois -boot
SWAP=
EOF

chmod +x environ
cat environ
