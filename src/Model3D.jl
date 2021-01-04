# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
# using GeometryBasics
import CoordinateTransformations: AffineMap, LinearMap, Translation
import GeometryBasics: Mat3f0, Vec3f0, Mesh, coordinates, faces, normals, texturecoordinates
import FileIO.load
import MeshIO.load
import Rotations: UnitQuaternion

import GLAbstraction

"""
A mesh with its current pose.
Simplifies draw calls by keeping track of the vertex array object and shader program.
"""
struct Model3D
    mesh::Mesh
    vao::GLAbstraction.VertexArray
    program::GLAbstraction.AbstractProgram

    function Model3D(mesh::Mesh, program::GLAbstraction.Program)
        # finds the order of the variables in the shader program and automatically assigns them correctly
        # the name of the buffer must match the variable name in the sahder program
        buffers = GLAbstraction.generate_buffers(
            program, GLAbstraction.GEOMETRY_DIVISOR,
            position=mesh.position,
            normal=mesh.normals,
            tex_coordinates=texturecoordinates(mesh))
        vao = GLAbstraction.VertexArray(buffers, faces(mesh))
        new(mesh, vao, program)
    end
end

Model3D(filename::AbstractString, program::GLAbstraction.Program) = Model3D(load(filename), program)

"""
    draw(model::Model3D)
Draws the model in its current state via its assigned shader program.
"""
function draw(model::Model3D, pose::AffineMap)
    to_gpu(model.program, "model", pose)
    GLAbstraction.bind(model.program)
    GLAbstraction.bind(model.vao)
    GLAbstraction.draw(model.vao)
    GLAbstraction.unbind(model.vao)
    GLAbstraction.unbind(model.program)
end
