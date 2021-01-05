module SciGL
__precompile__()

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
include("Scene.jl")
include("Transformations.jl")
include("Camera.jl")
include("MeshModel.jl")

# Export types
export CvCamera
export GLOrthoCamera
export MeshModel
export Pose
export SceneObject
export SceneType

# Export functions
export AffineMap
export Matrix
export SMatrix
export draw
export lookat
export to_gpu

end # module
