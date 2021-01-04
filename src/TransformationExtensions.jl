# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
"""
Common transformation functions for 3D rendering.
- Conversions
- Transfer to GPU
"""

"""
    augmented_matrix(M, v)
Converts an affine map consisting of a Matrix M and Vector v to an affine transformation matrix.
Returns an SMatrix which can be used with gluniform.
"""
augmented_matrix(M::Matrix{Float32}, v::Vector{Float32}) = SMatrix{4,4}([M v; 0 0 0 1])


"""
    augmented_matrix(a)
Converts an affine map to an affine transformation matrix.
Returns an SMatrix which can be used with gluniform.
"""
augmented_matrix(a::AffineMap) = augmented_matrix(Matrix{Float32}(a.linear), Vector{Float32}(a.translation))
