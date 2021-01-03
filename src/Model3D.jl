# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
# using GeometryBasics
import CoordinateTransformations.Translation
import GeometryBasics: Mesh, coordinates, faces, normals, texturecoordinates
import FileIO.load
import MeshIO.load
import Rotations.UnitQuaternion

import GLAbstraction

struct Model3D
    mesh::Mesh
    rotation::UnitQuaternion
    translation::Translation
    vao::GLAbstraction.VertexArray
    program::GLAbstraction.AbstractProgram

    function Model3D(mesh::Mesh, program::GLAbstraction.Program)
        buffers = GLAbstraction.generate_buffers(
            program, GLAbstraction.GEOMETRY_DIVISOR,
            position=mesh.position,
            normal=mesh.normals)
        vao = GLAbstraction.VertexArray(buffers, faces(mesh))
        new(mesh, UnitQuaternion(1, 0, 0, 0), Translation(0, 0, 0), vao, program)
    end
end

Model3D(filename::AbstractString, program::GLAbstraction.Program) = Model3D(load(filename), program)

function draw(model::Model3D)
    GLAbstraction.bind(model.program)
    GLAbstraction.bind(model.vao)
    GLAbstraction.draw(model.vao)
    GLAbstraction.unbind(model.vao)
    GLAbstraction.unbind(model.program)
end
