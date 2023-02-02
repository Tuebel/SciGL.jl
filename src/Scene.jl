# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using CoordinateTransformations
using Rotations

"""
    AbstractCamera
Abstract type of a camera, which is required in every scene.
Must support `projection_matrix(camera)` which returns a 4x4 SMatrix for the projection transformation to normalized device coordinates.
"""
abstract type AbstractCamera end

"""
    Pose{N}
Orientation and position of a scene object with dimensionality N.
"""
struct Pose{N,T<:Translation{<:SVector{N}},R<:Rotation{N}}
    translation::T
    rotation::R
end

"""
    Pose(t_xyz, r)
Pose from a translation vector and some rotation representation.
"""
Pose(t_xyz::AbstractVector, r) = Pose(Translation(t_xyz...), r)

"""
    one(Pose)
Returns a pose which results in the identity transformation.
"""
Base.one(::Type{<:Pose}) = Pose(Translation(0, 0, 0), one(QuatRotation))

Base.show(io::IO, p::Pose) = print(io, "Pose($(p.translation), Rotation$(p.rotation))")

"""
    SceneObject
Each object in a scene has a pose and a shader program attached to it
"""
struct SceneObject{T,P<:Pose,S<:Scale}
    object::T
    pose::P
    scale::S
end

"""
    SceneObject(object, program)
Creates a SceneObject with an identity rotation & zero translation
"""
SceneObject(object::T; pose=Pose(Translation(0, 0, 0), one(QuatRotation)), scale=Scale(1, 1, 1)) where {T} = SceneObject(object, pose, scale)

Base.show(io::IO, object::SceneObject{T}) where {T} = print(io, "SceneObject{$(T)}, pose: $(object.pose)")

"""
    Scene
A scene should consist of only one camera and several meshes.
In the future, lights could be supported for rendering RGB images.
"""
struct Scene{C<:SceneObject{<:AbstractCamera},U<:SceneObject{<:GLAbstraction.VertexArray}}
    camera::C
    meshes::Vector{U}
end

"""
    draw(program, scene)
Draws the whole scene via the given shader Program.
Transfers all the unions (matrices) to the shader Program.
"""
function draw(program::GLAbstraction.AbstractProgram, scene::Scene)
    # setup camera & lights before rendering meshes
    to_gpu(program, scene.camera)
    for so in scene.meshes
        draw(program, so)
    end
end
