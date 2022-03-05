#!/bin/sh
# Use NVIDIA card if prime profile on-demand is enabled

# Make this file executable via `chmod +x julia_nvidia.sh` and copy it to the directory which contains the julia executable

# Trick vscode that this file is the julia executable:
# VSCode setting: "julia.executablePath": "/path/to/julia/bin/julia_nvidia.sh"

DIR="$(cd "$(dirname "$0")" && pwd)"
JULIA=$DIR/julia
# VSCode does not like outputs here
# echo "Julia with OpenGL support via VirtualGL, executable: $JULIA"
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia $JULIA $*
