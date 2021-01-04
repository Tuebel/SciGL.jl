# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
import CoordinateTransformations: AffineMap, LinearMap, Translation
import GeometryBasics: Mat3f0, Vec3f0
import GLAbstraction: AbstractProgram
import Rotations: UnitQuaternion

# TODO Naming to vague?
function to_gpu(program::AbstractProgram, name::String, M::Mat3f0)
    name_symbol = Symbol(name * "_M")
    GLAbstraction.bind(program)
    # gluniform only seems to work with StaticArrays / GeometryBasics
    GLAbstraction.gluniform(program, name_symbol, M)
    GLAbstraction.unbind(program)
end

function to_gpu(program::AbstractProgram, name::String, v::Vec3f0)
    name_symbol = Symbol(name * "_v")
    GLAbstraction.bind(program)
    # gluniform only seems to work with StaticArrays / GeometryBasics
    GLAbstraction.gluniform(program, name_symbol, v)
    GLAbstraction.unbind(program)
end

function to_gpu(program::AbstractProgram, name::String, affine::AffineMap)
    to_gpu(program, name, Mat3f0(affine.linear))
    to_gpu(program, name, Vec3f0(affine.translation))
end
