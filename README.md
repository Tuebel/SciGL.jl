# SciGL.jl
Port of [scigl_render](https://gitlab.com/rwth-irt-public/flirt/scigl_render) to julia primarily targeted for Bayesian inference.

## Design decisions
I try to incorporate existing Julia packages wherever possible.
The next section contains a list and use cases of the packages

## Shader naming conventions
**Uniforms**:
- `mat4 model_matrix`: affine transformation matrix to transform model to world coordinates
- `mat4 view_matrix`: affine transformation matrix to transform world to view coordinates
- `mat4 projection_matrix`: perspective transformation matrix from view to clip coordinates
> **Warning** all matrix and vector uniforms must be StaticArrays of type `Float32`

**Vertex Shader Inputs**:
- `vec3 position`: vertex position in model coordinates
- `vec3 normal`: vertex normal in model coordinates
- `vec3 color`: vertex color in model coordinates

**Fragment Shader Inputs**:
- `vec3 model_color`: color of the fragment
- `vec3 model_normal`:  normal vector of the fragment in model coordinates
- `vec4 model_position`: position vector of the fragment in model coordinates
- `vec3 view_normal`: normal vector of the fragment in view coordinates
- `vec4 view_position`: position vector of the fragment in view coordinates
- `vec3 world_normal`: normal vector of the fragment in world coordinates
- `vec4 world_position`: position of the fragment in world coordinates

## Package Dependencies
- [CoordinateTransformations](https://github.com/JuliaGeometry/CoordinateTransformations.jl): Representing and chaining transformations like rotations, translations, and perspective transfromations.
  [Rotations](https://github.com/JuliaGeometry/Rotations.jl) are handled by the equally named package.
- [GLAbstractions](https://github.com/JuliaGL/GLAbstraction.jl): Takes some of the low level OpenGL pain away.
  Manages the context, compiles shaders and handles the buffers.
- [MeshIO](https://github.com/JuliaIO/MeshIO.jl): Load mesh files like *.obj*, *.ply*, and *.stl*.
  It uses the [FileIO](https://github.com/JuliaIO/FileIO.jl) interface, so this packages is also included.

# CudaGL.jl devcontainer
Recommended: Install the vscode [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) plugin and load the [devcontainer](https://code.visualstudio.com/docs/remote/containers).
Alternatively install julia locally, activate and instantia the SciGL.jl environment.

## Debug in vscode
The vscode julia debugger crashes when loading the native OpenGL functions.
Enabling the **Compiled Mode** as described [here](https://www.julia-vscode.org/docs/stable/userguide/debugging/) seems to be a workaround.

## IJupyter
Based on Jupyter, IJupyter can be used for explorative coding.
To use IJupyter, you have two choices:
- Create a *.ipynb* file and open it in vscode.
  The Jupyter extension will automatically launch the Jupyter server.
- Launch `jupyter lab --allow-root` from an integrated terminal.
  Hold Alt + Click the link to open the notebook.