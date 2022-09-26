# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

"""
    load_mesh(mesh, program)
Simplifies loading a Mesh into a VertexArray on the gpu.
"""
function load_mesh(program::GLAbstraction.AbstractProgram, mesh::Mesh)
    # finds the order of the variables in the shader program and automatically assigns them correctly
    # the name of the buffer must match the variable name in the shader program
    buffers = GLAbstraction.generate_buffers(
        program, GLAbstraction.GEOMETRY_DIVISOR,
        position=mesh.position,
        normal=mesh.normals,
        tex_coordinates=texturecoordinates(mesh))
    return GLAbstraction.VertexArray(buffers, faces(mesh))
end

"""
    load_mesh(program, mesh_file)
Simplifies loading a Mesh into a VertexArray on the gpu.
"""
load_mesh(program::GLAbstraction.AbstractProgram, mesh_file::AbstractString) = load_mesh(program, load(mesh_file))

"""
    to_gpu(program, scene_object)
Transfers the model matrix to the OpenGL program
"""
function to_gpu(program::GLAbstraction.AbstractProgram, scene_object::SceneObject{T}) where {T<:GLAbstraction.VertexArray}
    GLAbstraction.bind(program)
    GLAbstraction.gluniform(program, :model_matrix, SMatrix(scene_object.pose, scene_object.scale))
    GLAbstraction.unbind(program)
end

"""
    draw(program, scene_object)
Draws the model via the given shader Program.
**Warning:** the location of the unions in the must match those of the program used for the construction of the VertexArray.
"""
function draw(program::GLAbstraction.AbstractProgram, scene_object::SceneObject{T}) where {T<:GLAbstraction.VertexArray}
    GLAbstraction.bind(program)
    GLAbstraction.bind(scene_object.object)
    # Copied from to_gpu to avoid unnecessary bind / unbind
    GLAbstraction.gluniform(program, :model_matrix, SMatrix(scene_object.pose, scene_object.scale))
    GLAbstraction.draw(scene_object.object)
    GLAbstraction.unbind(scene_object.object)
    GLAbstraction.unbind(program)
end
