# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

"""
    Pose
Orientation and position of a scene object.
"""
mutable struct Pose
    R::Rotation
    t::Translation
end

"""
    SceneObject
Each object in a scene has a pose and a shader program attached to it
"""
struct SceneObject{T}
    object::T
    pose::Pose
end

"""
SceneObject(object, program)
Creates a SceneObject with an identity rotation & zero translation
"""
SceneObject(object::T; pose=Pose(one(UnitQuaternion), Translation(0, 0, 0))) where {T} = SceneObject(object, pose)