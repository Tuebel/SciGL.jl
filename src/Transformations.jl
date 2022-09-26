# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

"""
Common objects and transformation functions for 3D transformations.
"""

"""
    decompose(a::AbstractAffineMap)
Extract the linear map and translation as matrix and vector.
OpenGL requires element types of Float32.
"""
decompose(a::AffineMap{<:AbstractMatrix,<:SVector{N}}) where {N} = SMatrix{N,N,Float32}(a.linear), SVector{N,Float32}(a.translation)

"""
    augmented_matrix(M, v)
Converts a linear map and a translation vector to an augmented affine transformation matrix.
The matrix is of type Float32 for OpenGL
"""
function augmented_matrix(M::SMatrix{N,N}, v::SVector{N}) where {N}
    aug = zeros(Float32, N + 1)
    aug[end] = 1
    aug
    SMatrix{4,4,Float32}([M v; transpose(aug)])
end

# Convert to AffineMap
"""
    AffineMap(p::Pose)
Creates the active transformation by first rotating and then translating
"""
CoordinateTransformations.AffineMap(p::Pose) = AffineMap(p.rotation, p.translation.translation)

"""
    SMatrix(p::pose, s::Scale)
Creates the active transformation by first scaling, then rotating and finally translating
"""
CoordinateTransformations.AffineMap(p::Pose, s::Scale) = AffineMap(p) ∘ s

# Only SMatrix is supported because the mutable types don't play well with gluniform
"""
    SMatrix(a::AffineMap)
Converts an AffineMap to a static affine transformation matrix.
"""
StaticArrays.SMatrix(a::AbstractAffineMap) = augmented_matrix(decompose(a)...)

"""
    SMatrix(p::pose)
Converts a Pose to an affine transformation matrix.
Convention: (t ∘ r)(x)
"""
StaticArrays.SMatrix(p::Pose) = AffineMap(p) |> SMatrix

"""
    SMatrix(p::pose, s::Scale)
Converts a Pose and Scale to an affine transformation matrix.
Convention: (t ∘ r ∘ s)(x)
"""
StaticArrays.SMatrix(p::Pose, s::Scale) = AffineMap(p, s) |> SMatrix
