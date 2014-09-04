#!/bin/sh

cat > environ <<EOF
export FILE=example.v
export ERR_MESSAGE=Error
export BAD=trunk
export GOOD=v8.4
export CONFIGURE_ARGS="-nodoc -no-native-compiler"
export MAKE_TARGET=coqlight
export COQTOP_ARGS="-nois -boot"
export SWAP=
EOF

chmod +x environ
cat environ
