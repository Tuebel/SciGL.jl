__precompile__()

module SciGL

# Dependencies
using CoordinateTransformations
using GeometryBasics
using GLAbstraction
using FileIO
using MeshIO
using Rotations
using StaticArrays

# lib includes
include("Scene.jl")
include("Transformations.jl")
include("Camera.jl")
include("MeshModel.jl")

# Export types
export MeshModel
export Pose, SceneObject, SceneType

# Export functions
export AffineMap, Matrix, SMatrix
export draw, to_gpu

end # module
