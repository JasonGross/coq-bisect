#!/bin/sh

cat > environ <<EOF
export FILE=example.v
export ERR_MESSAGE=Error
export BAD=V8.12.0
export GOOD=V8.11.2
export CONFIGURE_ARGS="-nodoc -coqide no"
export MAKE_TARGET="coqocaml theories/Init/Prelude.vo"
export COQC_ARGS=" "
export SWAP=
EOF

chmod +x environ
cat environ
