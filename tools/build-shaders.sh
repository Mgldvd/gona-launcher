#!/bin/sh
# Compiles the effect shader(s) to the .qsb files the launcher loads (app/launcher/FxLayer.qml). Run it after editing
# app/shaders/*.frag and commit the .qsb next to the source: the plugin has no build step of its own, so what
# the shell loads is the compiled file. Needs qsb (Arch: qt6-shadertools, /usr/lib/qt6/bin/qsb).
# OUT=<dir> writes the results there instead (tests/verify.sh uses it to check the committed ones are current).
cd "$(dirname "$0")/../app/shaders" || exit 1
OUT="${OUT:-.}"
QSB="$(command -v qsb || echo /usr/lib/qt6/bin/qsb)"
for f in *.frag; do
    "$QSB" --qt6 --glsl "100 es,120,150,300 es,330" --hlsl 50 --msl 12 -o "$OUT/$f.qsb" "$f" || exit 1
    echo "built $f.qsb"
done
