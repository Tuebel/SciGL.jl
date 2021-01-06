# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
# using GeometryBasics

"""
    load_mesh(mesh, program)
Simplifies loading a VertexArray from a Mesh.
"""
function load_mesh(mesh::Mesh, program::GLAbstraction.AbstractProgram)
    # finds the order of the variables in the shader program and automatically assigns them correctly
    # the name of the buffer must match the variable name in the sahder program
    buffers = GLAbstraction.generate_buffers(
        program, GLAbstraction.GEOMETRY_DIVISOR,
        position=mesh.position,
        normal=mesh.normals,
        tex_coordinates=texturecoordinates(mesh))
    return GLAbstraction.VertexArray(buffers, faces(mesh))
end

"""
    load_mesh(mesh_file, program)
Simplifies loading a VertexArray from a mesh file.
"""
load_mesh(mesh_file::AbstractString, program::GLAbstraction.AbstractProgram) = load_mesh(load(mesh_file), program)

"""
    to_gpu(so, program)
Transfers the model matrix to the OpenGL program
"""
function to_gpu(so::SceneObject{T}, program::GLAbstraction.AbstractProgram) where{T<:GLAbstraction.VertexArray}
    GLAbstraction.bind(program)
    GLAbstraction.gluniform(program, :model_matrix, SMatrix(so.pose))
    GLAbstraction.unbind(program)
end

"""
    draw(so, program)
Draws the model via the given shader Program.
**Warning:** the location of the unions in the must match those of the program used for the construction of the VertexArray.  
Call `to_gpu` to update the pose in the shader program before this function.
"""
function draw(so::SceneObject{T}, program::GLAbstraction.AbstractProgram) where{T<:GLAbstraction.VertexArray}
    GLAbstraction.bind(program)
    GLAbstraction.bind(so.object)
    GLAbstraction.draw(so.object)
    GLAbstraction.unbind(so.object)
    GLAbstraction.unbind(program)
end
