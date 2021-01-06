__precompile__()

module SciGL

# Dependencies
using CoordinateTransformations
using GeometryBasics
using GLAbstraction
using FileIO
using MeshIO
using LinearAlgebra
using Rotations
using StaticArrays

# lib includes
include("BaseExtensions.jl")
include("Scene.jl")
include("Transformations.jl")
include("Camera.jl")
include("Shaders.jl")
include("MeshModel.jl")

# Scene types
export CvCamera
export GLOrthoCamera
export Pose
export SceneObject

# Shaders
export DepthFrag
export ModelNormalFrag
export NormalFrag
export SilhouetteFrag
export SimpleVert

# Export functions
export draw
export load_mesh
export lookat
export to_gpu

end # module
