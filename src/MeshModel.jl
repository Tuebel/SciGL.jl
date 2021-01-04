# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
# using GeometryBasics

"""
Stores a mesh model in the shader program.
"""
struct MeshModel <: SceneType
    vao::GLAbstraction.VertexArray
end
# TODO use VertexArray as MeshModel? Subclass SceneObject?
function MeshModel(mesh::Mesh, program::GLAbstraction.Program)
    # finds the order of the variables in the shader program and automatically assigns them correctly
    # the name of the buffer must match the variable name in the sahder program
    buffers = GLAbstraction.generate_buffers(
        program, GLAbstraction.GEOMETRY_DIVISOR,
        position=mesh.position,
        normal=mesh.normals,
        tex_coordinates=texturecoordinates(mesh))
    vao = GLAbstraction.VertexArray(buffers, faces(mesh))
    return MeshModel(vao)
end
MeshModel(filename::AbstractString, program::GLAbstraction.Program) = MeshModel(load(filename), program)

"""
    to_gpu(so::SceneObject{Camera})
Transfers the model matrix to the OpenGL program
"""
function to_gpu(so::SceneObject{MeshModel})
    GLAbstraction.bind(so.program)
    GLAbstraction.gluniform(so.program, :model_matrix, SMatrix(so.pose))
    GLAbstraction.unbind(so.program)
end

"""
    draw(so::SceneObject{MeshModel})
Draws the model via its assigned shader program.
Call `to_gpu` to update the pose in the shader program before this function.
"""
function draw(so::SceneObject{MeshModel})
    GLAbstraction.bind(so.program)
    GLAbstraction.bind(so.object.vao)

    GLAbstraction.draw(so.object.vao)

    GLAbstraction.unbind(so.object.vao)
    GLAbstraction.unbind(so.program)
end
