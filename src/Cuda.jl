# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.
using CUDA
using CUDA:
    CU_GRAPHICS_REGISTER_FLAGS_NONE,
    CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER,
    CU_RESOURCE_TYPE_ARRAY,
    CUarray,
    cuGraphicsGLRegisterImage,
    cuGraphicsMapResources,
    CUgraphicsResource,
    cuGraphicsSubResourceGetMappedArray,
    Mem
using GLAbstraction
using ModernGL

"""
    gltex_to_cuda_ptr(id)
Registers the texture or renderbuffer object specified by image for access by CUDA.
A CUarray pointer to the resource is returned.
"""
function gltex_to_cuda_ptr(id::GLuint; readonly = false) where {T}
    resources = Ref{CUDA.CUgraphicsResource}()
    # For reading also works: 
    if readonly
        flags = CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER
    else
        flags = CU_GRAPHICS_REGISTER_FLAGS_NONE
    end
    # resource as reference
    cuGraphicsGLRegisterImage(resources, id, GL_TEXTURE_2D, flags)
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
    ptr = gltex_to_cuda_ptr(src.id)
    Base.unsafe_copyto!(dest, ptr)
end

"""
    unsafe_copyto!(dest, src)
Copy a 2D texture to the CPU host memory.
CuMatrix type can differ from texture type if you know what you are doing (e.g. Flaot32 instead of Gray{Float32}).
Prefer the GLAbstraction version which requires the same type for both
"""
function Base.unsafe_copyto!(dest::Matrix{T}, src::GLAbstraction.Texture{U,2}) where {T,U}
    ptr = gltex_to_cuda_ptr(src.id)
    Base.unsafe_copyto!(dest, ptr)
end

# Mapping instead of copying, hopefully a pull request will make this copy pointless

"""
    SciTextureArray{T,N}
Basically a copy of the `CuTextureArray` from CUDA.jl but with an additional internal constructor which allows to pass an existing `ArrayBuffer`.
"""
mutable struct SciTextureArray{T,N}
    buf::Mem.ArrayBuffer{T}
    dims::Dims{N}
    ctx::CuContext

    @doc """
        SciTextureArray{T,N}(undef, dims)
    Construct an uninitialized texture array of `N` dimensions specified in the `dims`
    tuple, with elements of type `T`. Use `Base.copyto!` to initialize this texture array,
    or use constructors that take a non-texture array to do so automatically.
    """
    function SciTextureArray{T,N}(::UndefInitializer, dims::Dims{N}) where {T,N}
        buf = Mem.alloc(Mem.Array{T}, dims)
        t = new{T,N}(buf, dims, context())
        finalizer(unsafe_destroy!, t)
        return t
    end

    @doc """
        SciTextureArray{T,N}(buf, dims)
    Construct an uninitialized texture array of `N` dimensions specified in the `dims`
    tuple, with elements of type `T`. Use `Base.copyto!` to initialize this texture array,
    or use constructors that take a non-texture array to do so automatically.
    """
    function SciTextureArray(buf::Mem.ArrayBuffer{T,N}) where {T,N}
        t = new{T,N}(buf, buf.dims, context())
        finalizer(unsafe_destroy!, t)
        return t
    end
end

function unsafe_destroy!(t::SciTextureArray)
    context!(t.ctx; skip_destroyed = true) do
        Mem.free(t.buf)
    end
end

Base.size(tm::SciTextureArray) = tm.dims
Base.length(tm::SciTextureArray) = prod(size(tm))
Base.eltype(::SciTextureArray{T,N}) where {T,N} = T
Base.sizeof(tm::SciTextureArray) = sizeof(eltype(tm)) * length(tm)
Base.pointer(t::SciTextureArray) = t.buf.ptr
CUDA.memory_source(::SciTextureArray) = CUDA.ArrayMemory()

function CUDA.CUDA_RESOURCE_DESC(texarr::SciTextureArray)
    # FIXME: manual construction due to invalid padding (JuliaInterop/Clang.jl#238)
    resDesc_ref = Ref((CU_RESOURCE_TYPE_ARRAY, # resType::CUresourcetype
        pointer(texarr), # 1 x UInt64
        ntuple(_ -> Int64(0), 15), # 15 x UInt64
        UInt32(0)))
    return resDesc_ref
end

CUDA.CuTexture(x::SciTextureArray{T,N}; kwargs...) where {T,N} =
    CuTexture{T,N,typeof(x)}(x; kwargs...)


"""
    CuTexture(texture)
Map an OpenGL Texture to a CUDA Texture using the type of the texture.
Color types seem to cause problems with some Kernels.
"""
function CUDA.CuTexture(texture::GLAbstraction.Texture{T,N}) where {T,N}
    ptr = SciGL.gltex_to_cuda_ptr(texture.id)
    typed_ptr = Base.unsafe_convert(CuArrayPtr{T}, ptr)
    array_buf = CUDA.Mem.ArrayBuffer{T,N}(typed_ptr, size(texture))
    texture_array = SciGL.SciTextureArray(array_buf)
    CUDA.CuTexture(texture_array)
end

"""
    CuTexture(texture)
Map an OpenGL Texture to a CUDA Texture with an explicit type conversion.
"""
function CUDA.CuTexture(::Type{T}, texture::GLAbstraction.Texture{U,N}) where {T,U,N}
    ptr = SciGL.gltex_to_cuda_ptr(texture.id)
    typed_ptr = Base.unsafe_convert(CuArrayPtr{T}, ptr)
    array_buf = CUDA.Mem.ArrayBuffer{T,N}(context(), typed_ptr, size(texture))
    texture_array = SciGL.SciTextureArray(array_buf)
    CUDA.CuTexture(texture_array)
end
