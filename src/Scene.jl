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
    Camera
Abstract type of a camera, which is required in every scene
"""
abstract type Camera end

"""
    Scene
A scene should consist of only one camera and several meshes.
In the future, lights could be supported for rendering RGB images.
"""
mutable struct Scene
    camera::SceneObject{T} where {T <: Camera}
    meshes::AbstractVector{SceneObject{T}} where {T <: GLAbstraction.VertexArray}
end

"""
    SceneObject(object, program)
Creates a SceneObject with an identity rotation & zero translation
"""
SceneObject(object::T; pose=Pose(one(UnitQuaternion), Translation(0, 0, 0))) where {T} = SceneObject(object, pose)

"""
    draw(program, scene_object)
Draws the whole scene via the given shader Program.
Transfers all the unions (matrices) to the shader Program.
"""
function draw(program::GLAbstraction.AbstractProgram, scene::Scene)
    # setup camera & lights before rendering meshes
    to_gpu(program, scene.camera)
    for so in scene.meshes
        to_gpu(program, so)
        draw(program, so)
    end
end