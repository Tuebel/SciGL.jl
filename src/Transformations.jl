# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
"""
Common objects and transformation functions for 3D transformations.
"""

"""
    decompose(a::AbstractAffineMap)
Extract the linear map and translation as matrix and vector.
They are of type Float32 for OpenGL
"""
decompose(a::AbstractAffineMap) = SMatrix{3,3,Float32}(a.linear), SVector{3,Float32}(a.translation)

# Convert to AffineMap

"""
    affine_map(R::Rotation, t::Translation)
Creates the active transformation by first rotating and then translating
"""
affine_map(R::Rotation, t::Translation) = t ∘ LinearMap(R)

"""
  AffineMap(p::Pose)
Creates the active transformation by first rotating and then translating
"""
CoordinateTransformations.AffineMap(p::Pose) = affine_map(p.R, p.t)

# Convert to affine transformation matrix.
# Only SMatrix is supported because the mutable types don't play well with gluniform

"""
    augmented_matrix(M, v)
Converts a linear map and a translation vector to an augmented affine transformation matrix.
The matrix is of type Float32 for OpenGL
"""
augmented_matrix(M::SMatrix{3,3}, v::SVector{3}) = SMatrix{4,4,Float32}([M v; 0 0 0 1])

"""
    SMatrix(a::AffineMap)
Converts an AffineMap to a static affine transformation matrix.
"""
StaticArrays.SMatrix(a::AbstractAffineMap) = decompose(a)... |> augmented_matrix

"""
    SMatrix(p::pose)
Converts a Pose to an affine transformation matrix.
"""
StaticArrays.SMatrix(p::Pose) = AffineMap(p) |> SMatrix
