module SciGL

# Dependencies
using CoordinateTransformations
using GeometryBasics
using GLAbstraction
using FileIO
using MeshIO
using Rotations
using StaticArrays

# This lib
include("Model3D.jl")
include("TransformationExtensions.jl")

# Export types
export Model3D

# Export functions
export draw

end # module
