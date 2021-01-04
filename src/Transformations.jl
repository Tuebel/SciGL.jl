# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
"""
Common objects and transformation functions for 3D transformations.
"""

# Helpers for decomposition and piping
import Base.|>

|>(x,y,f) = f(x, y)

decompose(a::AbstractAffineMap) = Matrix(a.linear), Vector(a.translation)

# Convert to AffineMap

"""
  AffineMap(R::Rotation, t::Translation)
Creates the active transformation by first rotating and then translating
"""
CoordinateTransformations.AffineMap(R::Rotation, t::Translation) = t ∘ LinearMap(R)

"""
  AffineMap(p::Pose)
Creates the active transformation by first rotating and then translating
"""
CoordinateTransformations.AffineMap(p::Pose) = AffineMap(p.R, p.t)

# Convert to affine transformation matrix

"""
    Matrix(M::AbstractMatrix, v::AbstractVector)
Converts a linear map and a translation vector to an augmented affine transformation matrix.
"""
Base.Matrix(M::AbstractMatrix, v::AbstractVector) = Matrix([M v; 0 0 0 1])

"""
    Matrix(a::AffineMap)
Converts an AffineMap to an affine transformation matrix.
"""
Base.Matrix(a::AbstractAffineMap) = decompose(a)... |> Matrix

"""
    Matrix(p::pose)
Converts a Pose to an affine transformation matrix.
"""
Base.Matrix(p::Pose) = AffineMap(p) |> Matrix

# Convert to SMatrix for use in gluniform
"""
    SMatrix(a::AffineMap)
Converts an AffineMap to a static affine transformation matrix.
"""
StaticArrays.SMatrix(a::AbstractAffineMap) = Matrix(a) |> SMatrix{4,4}

"""
    SMatrix(p::pose)
Converts a Pose to an static affine transformation matrix.
"""
StaticArrays.SMatrix(p::Pose) = Matrix(p) |> SMatrix{4,4}

# TODO force floats
