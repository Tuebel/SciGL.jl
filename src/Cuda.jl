# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.
using CUDA
using CUDA:
    CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER,
    CUarray,
    cuGraphicsGLRegisterImage,
    cuGraphicsMapResources,
    CU_GRAPHICS_REGISTER_FLAGS_NONE,
    CUgraphicsResource,
    cuGraphicsSubResourceGetMappedArray,
    Mem
using GLAbstraction
using ModernGL

"""
    cuda_array_ptr(tex)
Registers the texture or renderbuffer object specified by image for access by CUDA.
A CUarray pointer to the resource is returned.
"""
function cuda_array_ptr(tex::GLAbstraction.Texture{T,2}; readonly = false) where {T}
    resources = Ref{CUDA.CUgraphicsResource}()
    # For reading also works: 
    if readonly
        flags = CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER
    else
        flags = CU_GRAPHICS_REGISTER_FLAGS_NONE
    end
    # resource as reference
    cuGraphicsGLRegisterImage(resources, tex.id, GL_TEXTURE_2D, flags)
    cuGraphicsMapResources(1, resources, C_NULL)
    cuarray_ptr = Ref{CUarray}()
    # resources dereferenced
    cuGraphicsSubResourceGetMappedArray(cuarray_ptr, resources[], 0, 0)
    cuarray_ptr[]
end

# TODO renderbuffer fails with invalid
# function cuda_register_image(tex::GLAbstraction.RenderBuffer)
#     resources = Ref{CUgraphicsResource}()
#     flags = CU_GRAPHICS_REGISTER_FLAGS_NONE
#     CUDA.cuGraphicsGLRegisterImage(resources, tex.id, GL_RENDERBUFFER, flags)
#     resources[]
# end

"""
    unsafe_copyto!(dest, src)
Copy a 2D graphics resource to the host memory.
"""
function Base.unsafe_copyto!(dest::Matrix{T}, src::CUarray) where {T}
    src_ptr = Base.unsafe_convert(CuArrayPtr{T}, src)
    width, height = size(dest)
    Mem.unsafe_copy2d!(pointer(dest), Mem.Host, src_ptr, Mem.Array, width, height)
end

"""
    unsafe_copyto!(dest, src)
Copy a 2D graphics resource to the CUDA device memory.
"""
function Base.unsafe_copyto!(dest::CuMatrix{T}, src::CUarray) where {T}
    typed_ptr = Base.unsafe_convert(CuArrayPtr{T}, src)
    width, height = size(dest)
    # TODO somehow wrap instead of copying like https://gist.github.com/watosar/471f0f6b20d5dd18753b87c497d9a36d
    Mem.unsafe_copy2d!(pointer(dest), Mem.Device, typed_ptr, Mem.Array, width, height)
end

"""
    unsafe_copyto!(dest, src)
Copy a 2D texture to the CUDA device memory.
CuMatrix type can differ from texture type if you know what you are doing (e.g. Flaot32 instead of Gray{Float32})
"""
function Base.unsafe_copyto!(dest::CuMatrix{T}, src::GLAbstraction.Texture{U,2}) where {T,U}
    ptr = cuda_array_ptr(src)
    Base.unsafe_copyto!(dest, ptr)
end

"""
    unsafe_copyto!(dest, src)
Copy a 2D texture to the CPU host memory.
CuMatrix type can differ from texture type if you know what you are doing (e.g. Flaot32 instead of Gray{Float32}).
Prefer the GLAbstraction version which requires the same type for both
"""
function Base.unsafe_copyto!(dest::Matrix{T}, src::GLAbstraction.Texture{U,2}) where {T,U}
    ptr = cuda_array_ptr(src)
    Base.unsafe_copyto!(dest, ptr)
end