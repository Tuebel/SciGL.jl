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

function (scale::Scale)(x)
    x .* scale.scale
end

"""
    scale(mesh)
Scale the GeometryBasics Mesh using a Scale transformation.
"""
function (scale::Scale)(mesh::Mesh)
    # OpenGL uses Float32 by default
    scale = Scale(Float32.(scale.scale))
    # Quite fragile to not rely on functions but works like MeshIO.jl
    point_attributes = Dict{Symbol,Any}()
    if hasproperty(mesh, :normals)
        point_attributes[:normals] = mesh.normals
    end
    if hasproperty(mesh, :uv)
        point_attributes[:uv] = mesh.uv
    end
    if hasproperty(mesh, :uvw)
        point_attributes[:uvw] = mesh.uvw
    end
    points = Point.(scale.(mesh.position))
    Mesh(meta(points; point_attributes...), faces(mesh))
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
