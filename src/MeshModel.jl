# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

"""
    upload_mesh(program, mesh)
Upload a Mesh to the GPU as VertexArray.
"""
function upload_mesh(program::GLAbstraction.AbstractProgram, mesh::Mesh)
    # Avoid transferring unavailable attributes
    program_attributes = tuple(getproperty.(GLAbstraction.attributes(program), :name)...)
    mesh_attributes = (;
        position=mesh.position,
        normal=normals(mesh),
        tex_coordinates=texturecoordinates(mesh))
    intersect_attributes = NamedTuple{program_attributes}(mesh_attributes)
    @debug "Attributes unavailable in shader program: $(Base.structdiff(mesh_attributes, intersect_attributes) |> keys)"
    # finds the order of the variables in the shader program and automatically assigns them correctly
    buffers = GLAbstraction.generate_buffers(program; intersect_attributes...)
    return GLAbstraction.VertexArray(buffers, faces(mesh)) |> SceneObject
end

"""
    upload_mesh(program, mesh_file)
Load a mesh from a file an upload it to the GPU as VertexArray.
"""
upload_mesh(program::GLAbstraction.AbstractProgram, mesh_file::AbstractString) = upload_mesh(program, load(mesh_file))

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
    GLAbstraction.gluniform(program, :model_matrix, SMatrix(scene_object.pose))
    GLAbstraction.draw(scene_object.object)
    GLAbstraction.unbind(scene_object.object)
    GLAbstraction.unbind(program)
end
