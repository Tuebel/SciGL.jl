__precompile__()

module SciGL

# Dependencies
# TODO not use whole libs
using ColorTypes: AbstractRGBA, RGB, RGBA, red, blue, green, alpha
using CoordinateTransformations
using FixedPointNumbers: N0f8, Normed
using GeometryBasics
using GLAbstraction
using GLFW
using FileIO
using MeshIO
using ModernGL
using LinearAlgebra
using Rotations
using StaticArrays

# lib includes
include("BaseExtensions.jl")
include("Scene.jl")
include("RenderContexts.jl")
include("Transformations.jl")
include("Camera.jl")
include("Shaders.jl")
include("MeshModel.jl")
include("FrameBuffer.jl")

# Scene types
export CvCamera
export GLOrthoCamera
export Pose
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
export context_fullscreen
export context_offscreen
export context_window
export depth_framebuffer
export draw
export enable_depth_stencil
export load_mesh
export lookat
export set_clear_color
export to_gpu

end # module
