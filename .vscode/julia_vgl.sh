#!/bin/sh
# Use VirtualGL to enable OpenGL on headless servers

# Make this file executable via `chmod +x julia_vgl.sh` and copy it to the directory which contains the julia executable

# Trick vscode that this file is the julia executable:
# VSCode setting: "julia.executablePath": "/path/to/julia/bin/julia_vgl.sh"

DIR="$(cd "$(dirname "$0")" && pwd)"
JULIA=$DIR/julia

# VSCode reads the ouputs of julia -e using Pkg; println.(Pkg.depots())
# echo "Julia with OpenGL support via VirtualGL, executable: $JULIA"
DISPLAY=:0 vglrun -d /dev/dri/card0 $JULIA "$@"
