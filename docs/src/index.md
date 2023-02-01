# SciGL.jl
Port of [scigl_render](https://gitlab.com/rwth-irt-public/flirt/scigl_render) to julia.

The primary goal is to enable efficient rendering of multiple scenes and transferring the images to a compute device (CPU or CUDA) for **Sci**entific calculations.

This is achieved by rendering to different layers of a 3D texture `(width, height, depth)` via `glFramebufferTextureLayer`.
Pixel pack buffer objects are used to transfer data from OpenGL to the CPU or CUDA.
Have a look at [OffscreenContext](@ref) which provides a simple interface for rendering and transferring the data.

# Conventions

## Camera and image conventions
The `OpenCV` camera uses the OpenCV conventions which means:
* X: right
* Y: down (OpenGL up)
* Z: forward (OpenGL backward)

Moreover, the resulting images have the origin in the top-left compared to the bottom-left in OpenGL.
Consequently, renderings appear upside down in OpenGL context windows but upright in memory, e.g. when copying from textures to CPU or CUDA arrays.

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

## Example meshes
In *examples/meshes* you can find two meshes:
* *cube.obj* is a simple cube of size (1,1,1) meter.
* *monkey.obj* is the Blender Suzanne with Z pointing up and the face pointing in X direction. Size is (0.632, 1, 0.72) meters.
