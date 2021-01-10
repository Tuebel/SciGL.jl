# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

"""
    gpu_data(t::Texture{T, ND})
Implementing the GPUArray interface.
"""
function GLAbstraction.gpu_data(t::GLAbstraction.Texture{T, ND}) where {T, ND}
    # Original zeros does not work for ColorTypes images
    result = rand(T, size(t)...)
    unsafe_copyto!(result, t)
    return result
end