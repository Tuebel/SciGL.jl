# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

module SciGL

# Dependencies
using ColorTypes: AbstractRGBA, RGB, RGBA, Gray, red, blue, green, alpha
using CoordinateTransformations
# TODO maybe create another package SciCuGL which has CUDA in its dependencies and precompiles it
using CUDA
using FixedPointNumbers: N0f8, Normed
using GeometryBasics
# TODO Either take over the development or roll my own Package
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
include("Transformations.jl")
include("Camera.jl")
include("Shaders.jl")
include("MeshModel.jl")
include("FrameBuffer.jl")
include("Layers.jl")
include("PersistentBuffer.jl")
include("Cuda.jl")
include("RenderContexts.jl")
include("OffscreenContext.jl")

# Scene types
export AbstractCamera
export Camera
export CvCamera
export OrthographicCamera

export Pose
export Scale
export SceneObject
export Scene

# Shaders
export DepthFrag
export DistanceFrag
export ModelNormalFrag
export NormalFrag
export SilhouetteFrag
export SimpleVert

# Export functions
export clear_buffers
export color_framebuffer
export color_framebuffer_rbo
export crop
export depth_framebuffer
export depth_framebuffer_rbo
export draw
export enable_depth_stencil
export load_mesh
export lookat
export set_clear_color
export to_gpu

# Layered rendering
export activate_layer

# PersistentBuffer
export PersistentBuffer

# Context
export context_fullscreen
export context_offscreen
export context_window
export depth_offscreen_context
export destroy_context
export OffscreenContext

# CUDA
export async_copyto!, sync_buffer
export cuda_interop_available
export map_resource, unmap_resource

# Reexport
using Reexport
@reexport begin
    import ColorTypes: AbstractRGBA, RGB, RGBA, Gray, red, blue, green, alpha
    import CoordinateTransformations: AffineMap, LinearMap, Translation
    import FileIO: load
    import GLAbstraction
    import GLAbstraction: color_attachments, gpu_data
    import GLFW

    using Rotations
end

# Aliases
compile_shader = GLAbstraction.Program
export compile_shader
glbind = GLAbstraction.bind
export glbind
glunbind = GLAbstraction.bind
export glunbind

end # module
