[![Run Tests](https://github.com/rwth-irt/SciGL.jl/actions/workflows/run_tests.yml/badge.svg)](https://github.com/rwth-irt/SciGL.jl/actions/workflows/run_tests.yml)
[![Documenter](https://github.com/rwth-irt/SciGL.jl/actions/workflows/documenter.yml/badge.svg)](https://github.com/rwth-irt/SciGL.jl/actions/workflows/documenter.yml)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://rwth-irt.github.io/SciGL.jl)

# About
This code has been produced during while writing my Ph.D. (Dr.-Ing.) thesis at the institut of automatic control, RWTH Aachen University.
If you find it helpful for your research please cite this:
> T. Redick, „Bayesian inference for CAD-based pose estimation on depth images for robotic manipulation“, RWTH Aachen University, 2024. doi: [10.18154/RWTH-2024-04533](https://doi.org/10.18154/RWTH-2024-04533).

# SciGL.jl
Port of [scigl_render](https://gitlab.com/rwth-irt-public/flirt/scigl_render) to julia.

The primary goal is to enable efficient rendering of multiple scenes and transferring the images to a compute device (CPU or CUDA) for **Sci**entific calculations.

# Design decisions
I try to incorporate existing Julia packages wherever possible.
The next section contains a list and use cases of the packages.

For performance, I use *Persistent mapping* and `glGetTextureSubImage` to transfer data between the GPU and CPU.
These functions require **OpenGL 4.5**, but I set the minimum version to **4.1** to support WSL2.
It seems like the drivers support the functions nevertheless.

## Package Dependencies
- [CoordinateTransformations](https://github.com/JuliaGeometry/CoordinateTransformations.jl): Representing and chaining transformations like rotations, translations, and perspective transformations.
  [Rotations](https://github.com/JuliaGeometry/Rotations.jl) are handled by the equally named package.
- [GLAbstractions](https://github.com/Tuebel/GLAbstraction.jl): Takes some of the low-level OpenGL pain away.
  Manages the context, compiles shaders, and handles the buffers.
- [ModernGL](https://github.com/JuliaGL/ModernGL.jl): Used by GLAbstractions to interface with the OpenGL driver.
- [GLFW](https://github.com/JuliaGL/GLFW.jl): OpenGL context handling.
- [MeshIO](https://github.com/JuliaIO/MeshIO.jl): Load mesh files like *.obj*, *.ply*, and *.stl*.
  It uses the [FileIO](https://github.com/JuliaIO/FileIO.jl) interface, so this package is also included.

## Reexport
For convenience commonly used symbols are reexported:
- ColorTypes: AbstractRGBA, RGB, RGBA, Gray, red, blue, green, alpha
- CoordinateTransformations: Translation
- GLAbstraction
- GLFW
- Rotations: all symbols

# HPC on Headless Server with VirtualGL
Install [TurboVNC](https://turbovnc.org/Documentation/Documentation) on the server which will be used to instantiate a render context without an attached display.
There are also good [instructions](https://github.com/JuliaGL/GLVisualize.jl/issues/146#issuecomment-289242168) on the GLVisualize github.

Use the following script to launch julia with TurboVNC and NVIDIA as OpenGL vendor:
```bash
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
JULIA=$DIR/julia
# VSCode reads the ouputs of julia -e using Pkg; println.(Pkg.depots())
/opt/TurboVNC/bin/vncserver :6
DISPLAY=:6 __GLX_VENDOR_LIBRARY_NAME=nvidia $JULIA "$@"%
```

Make the file executable via `chmod +x julia_nvidia.sh`

Moreover, you can trick vscode that this file is the julia executable via the setting: "julia.executablePath": "/path/to/julia/bin/julia_nvidia.sh"

> **Tipp:** If you get an unknown CUDA Error (999) during OpenGL interop, you probably render to the integrated device instead of the NVIDIA

# OpenGL.jl devcontainer
Recommended: Install the vscode [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) plugin and load the [devcontainer](https://code.visualstudio.com/docs/remote/containers).
Alternatively install julia locally, activate and instantia the SciGL.jl environment.

## Docker + GPU
On Ubuntu 20.04 and other recent Linux distros, NVIDIA allows for on-demand switching between dedicated and integrated graphics.
This allows to save electricity by only using the dedicated GPU when required.
A choice of Intel or NVIDIA GPUs can be made by (un)commenting the specific lines of the `runArgs` and `containerEnv` in [devcontainer.json](.devcontainer/devcontainer.json).
Alternatively, you could run julia with the environment variables set:
```shell
# NVIDIA GPU
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia julia script.
# Integrated graphics
__GLX_VENDOR_LIBRARY_NAME=mesa julia script.jl
```
You can verify whether the NVIDIA GPU is used in a Julia program by the following command on the host:
```shell
nvidia-smi | grep julia
```

## Windows Subsystem for Linux (WSL2)
Microsoft [added](https://devblogs.microsoft.com/commandline/d3d12-gpu-video-acceleration-in-the-windows-subsystem-for-linux-now-available/) the Direct3D backend to the mesa driver in WSL2.
One drawback is that the driver version is not the latest, e.g., 4.2 for NVIDIA and 4.1 for Intel at the time of writing.
You can switch between the GPUs by setting the following environment variable:
```shell
MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA julia
MESA_D3D12_DEFAULT_ADAPTER_NAME=Intel julia
```


## Debug in vscode
Later versions of the Julia extension seem to have fixed the issue.

The vscode julia debugger crashes when loading the native OpenGL functions.
Enabling the **Compiled Mode** as described [here](https://www.julia-vscode.org/docs/stable/userguide/debugging/) seems to be a workaround.

## IJupyter
Based on Jupyter, IJupyter can be used for explorative coding.
To use IJupyter, you have two choices:
- Create a *.ipynb* file and open it in vscode.
  The Jupyter extension will automatically launch the Jupyter server.
- Launch `jupyter lab --allow-root` from an integrated terminal.
  Hold Alt + Click the link to open the notebook.
