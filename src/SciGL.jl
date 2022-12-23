# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

module SciGL

# Dependencies
# TODO not use whole libs
using ColorTypes: AbstractRGBA, RGB, RGBA, Gray, red, blue, green, alpha
using CoordinateTransformations
using CUDA
using FixedPointNumbers: N0f8, Normed
using GeometryBasics
using GLAbstraction
using GLFW
using FileIO
using Logging
using MeshIO
using ModernGL
using LinearAlgebra
using Rotations
using StaticArrays

# lib includes
include("CoordinateTransformationExtensions.jl")
include("Scene.jl")
include("RenderContexts.jl")
include("Transformations.jl")
include("Camera.jl")
include("Shaders.jl")
include("MeshModel.jl")
include("FrameBuffer.jl")
include("Layers.jl")
include("Tiles.jl")
include("Sync.jl")
include("PersistentBuffer.jl")
include("Cuda.jl")

# Scene types
export CvCamera
export GLOrthoCamera
export Pose
export Scale
export SceneObject
export Scene

# Shaders
export DepthFrag
export ModelNormalFrag
export NormalFrag
export SilhouetteFrag
export SimpleVert

# Export functions
export clear_buffers
export color_framebuffer
export color_framebuffer_rbo
export context_fullscreen
export context_offscreen
export context_window
export depth_framebuffer
export depth_framebuffer_rbo
export draw
export enable_depth_stencil
export load_mesh
export lookat
export set_clear_color
export to_gpu

# Tiled rendering
export Tiles

export activate_all
export activate_tile
export coordinates
export tile_length
export tile_size
export full_size

# Layered rendering
export activate_layer

# Synchronized rendering of tiles
export render_channel
export draw_to_cpu
export draw_to_cpu_async

# PersistentBuffer
export PersistentBuffer

# CUDA
export async_copyto!, sync_buffer
export cuda_interop_available
export map_resource, unmap_resource

# Reexport
using Reexport
@reexport begin
    import ColorTypes: AbstractRGBA, RGB, RGBA, Gray, red, blue, green, alpha
    import CoordinateTransformations: AffineMap, LinearMap, Translation
    import GLAbstraction
    import GLAbstraction: gpu_data
    import GLFW

    using Rotations
end

using SnoopPrecompile
@precompile_all_calls begin
    WIDTH = 800
    HEIGHT = 600

    # attachments and data transfer
    window = context_offscreen(WIDTH, HEIGHT)
    color_framebuffer(WIDTH, HEIGHT, 3)
    color_framebuffer_rbo(WIDTH, HEIGHT)
    framebuffer = depth_framebuffer(WIDTH, HEIGHT, 3)
    enable_depth_stencil()
    set_clear_color()

    texture = first(GLAbstraction.color_attachments(framebuffer))
    pbo = PersistentBuffer(texture)
    data = Array(pbo)
    if cuda_interop_available()
        CuArray(pbo)
    end

    # Scene
    camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject

    silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
    load_mesh(silhouette_prog, "examples/meshes/cube.obj") |> SceneObject
    depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)
    load_mesh(depth_prog, "examples/meshes/cube.obj") |> SceneObject
    normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
    cube = load_mesh(normal_prog, "examples/meshes/cube.obj") |> SceneObject
    scene = SciGL.Scene(camera, [cube])

    Translation(1.3 * sin(2π), 0, 1.5 * cos(2π))
    lookat(scene.camera, cube, [0 1 0])

    # Draw to framebuffer and copy to pbo
    GLAbstraction.bind(framebuffer)
    activate_layer(framebuffer, 1)
    clear_buffers()
    draw(silhouette_prog, scene)
    draw(depth_prog, scene)
    draw(normal_prog, scene)
    unsafe_copyto!(pbo, framebuffer)

    # Finalize
    GLFW.DestroyWindow(window)
end

end # module
