# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 


"""
    Scale
Affine independent scaling of the dimensions.
"""
struct Scale{V} <: AbstractAffineMap
    scale::V
end

Scale(x::Tuple) = Scale(SVector(x))
Scale(x, y) = Scale(SVector(x, y))
Scale(x, y, z) = Scale(SVector(x, y, z))
Base.show(io::IO, scale::Scale) = print(io, "Scale$((scale.scale...,))")

function (scale::Scale{V})(x) where {V}
    x .* scale.scale
end

Base.inv(scale::Scale) = Scale(1 ./ scale.scale)

function CoordinateTransformations.compose(scale1::Scale, scale2::Scale)
    Scale(scale1.scale .* scale2.scale)
end

function CoordinateTransformations.compose(scale::Scale, affine::AffineMap)
    AffineMap(scale_diag(scale.scale) * affine.linear, scale.scale .* affine.translation)
end

function CoordinateTransformations.compose(affine::AffineMap, scale::Scale)
    AffineMap(affine.linear * scale_diag(scale.scale), affine.translation)
end

function CoordinateTransformations.compose(affine::LinearMap, scale::Scale)
    LinearMap(affine.linear * scale_diag(scale.scale))
end

function CoordinateTransformations.compose(scale::Scale, affine::LinearMap)
    LinearMap(scale_diag(scale.scale) * affine.linear)
end

scale_diag(scale) = SDiagonal(scale)
scale_diag(scale::Real) = scale

CoordinateTransformations.transform_deriv(scale::Scale, ::Any) = scale_diag(scale.scale)

function Base.isapprox(scale1::Scale, scale2::Scale; kwargs...)
    isapprox(scale1.scale, scale2.scale; kwargs...)
end
