# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

using CUDA:
    CU_GRAPHICS_REGISTER_FLAGS_NONE,
    CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER,
    CU_RESOURCE_TYPE_ARRAY,
    CuArrayPtr,
    cuGraphicsGLRegisterImage,
    cuGraphicsMapResources,
    CUgraphicsResource,
    cuGraphicsSubResourceGetMappedArray,
    Mem

# Map an OpenGL texture to a CuTexture.
# Addressing is not linear but optimized for interpolation.
# These are represented by CUDA Arrays instead of device pointers and are indexed by Floats.

"""
    gltex_to_cuarrayptr(id)
Registers the texture for access by CUDA.
A CuArrayPtr to the resource is returned.
"""
function gltex_to_cuarrayptr(texture::GLAbstraction.Texture{<:Any,N}; readonly=false) where {N}
    resources = Ref{CUDA.CUgraphicsResource}()
    # For reading also works: 
    if readonly
        flags = CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER
    else
        flags = CU_GRAPHICS_REGISTER_FLAGS_NONE
    end
    # resource as reference
    cuGraphicsGLRegisterImage(resources, texture.id, GLAbstraction.texturetype_from_dimensions(N), flags)
    cuGraphicsMapResources(1, resources, C_NULL)
    cuarray_ptr = Ref{CuArrayPtr{Cvoid}}()
    # resources dereferenced
    cuGraphicsSubResourceGetMappedArray(cuarray_ptr, resources[], 0, 0)
    cuarray_ptr[]
end

"""
    unsafe_copyto!(dest, src)
Copy an OpenGL texture to an Array.
The array type can differ from texture type if you know what you are doing (e.g. Float32 instead of Gray{Float32})
"""
function Base.unsafe_copyto!(dest::AbstractArray{T,N}, src::GLAbstraction.Texture{U,N}) where {T,U,N}
    ptr = Base.unsafe_convert(CuArrayPtr{T}, gltex_to_cuarrayptr(src))
    unsafe_copyto!(dest, ptr)
end

Base.unsafe_copyto!(dest::AbstractArray, src::GLAbstraction.FrameBuffer) = unsafe_copyto!(dest, first(GLAbstraction.color_attachments(src)))

"""
    unsafe_copyto!(dest, src)
Copy the first attachment of an OpenGL framebuffer to an Array.
The array type can differ from texture type if you know what you are doing (e.g. Float32 instead of Gray{Float32})
"""
Base.unsafe_copyto!(dest::CuArray{T,2}, src::CuArrayPtr{T}) where {T} = Mem.unsafe_copy2d!(pointer(dest), Mem.Device, src, Mem.Array, size(dest)...)
Base.unsafe_copyto!(dest::Array{T,2}, src::CuArrayPtr) where {T} = Mem.unsafe_copy2d!(pointer(dest), Mem.Host, src, Mem.Array, size(dest)...)

Base.unsafe_copyto!(dest::CuArray{T,3}, src::CuArrayPtr{T}) where {T} = Mem.unsafe_copy3d!(pointer(dest), Mem.Device, src, Mem.Array, size(dest)...)
Base.unsafe_copyto!(dest::Array{T,3}, src::CuArrayPtr) where {T} = Mem.unsafe_copy3d!(pointer(dest), Mem.Host, src, Mem.Array, size(dest)...)

# TODO Pull request for the internal constructor which accepts an existing ArrayBuffer instead of allocating one.
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
    context!(t.ctx; skip_destroyed=true) do
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
Map an OpenGL Texture to a CUDA Texture with an explicit type conversion.
"""
function CUDA.CuTexture(::Type{T}, texture::GLAbstraction.Texture{<:Any,N}) where {T,N}
    ptr = SciGL.gltex_to_cuarrayptr(texture)
    typed_ptr = Base.unsafe_convert(CuArrayPtr{T}, ptr)
    array_buf = CUDA.Mem.ArrayBuffer{T,N}(context(), typed_ptr, size(texture))
    texture_array = SciGL.SciTextureArray(array_buf)
    CUDA.CuTexture(texture_array)
end

"""
    CuTexture(texture)
Map an OpenGL Texture to a CUDA Texture using the type of the texture.
Color types seem to cause problems with some Kernels.
"""
CUDA.CuTexture(texture::GLAbstraction.Texture{T,N}) where {T,N} = CuTexture(T, texture)


# TODO This note is from https://github.com/JuliaGPU/CUDA.jl/blob/master/src/texture.jl but I could not get ArrayBuffer working with CuArray because of illegal conversions
# NOTE: the API for texture support is not final yet. some thoughts:
#
# - instead of CuTextureArray, use CuArray with an ArrayBuffer. This array could then
#   adapt to a CuTexture, or do the same for CuDeviceArray.

# function CUDA.CuArray(texture::GLAbstraction.Texture{T,N}) where {T,N}
#     ptr = SciGL.gltex_to_cuda_ptr(texture)
#     typed_ptr = Base.unsafe_convert(CuArrayPtr{T}, ptr)
#     array_buf = CUDA.Mem.ArrayBuffer{T,N}(context(), typed_ptr, size(texture))
#     storage = CUDA.ArrayStorage(array_buf, 1)
#     CuArray{T,N}(storage, size(texture))
# end

# function CUDA.CuArray(::Type{T}, texture::GLAbstraction.Texture{<:Any,N}) where {T,N}
#     ptr = SciGL.gltex_to_cuda_ptr(texture)
#     typed_ptr = Base.unsafe_convert(CuArrayPtr{T}, ptr)
#     array_buf = CUDA.Mem.ArrayBuffer{T,N}(context(), typed_ptr, size(texture))
#     storage = CUDA.ArrayStorage(array_buf, 1)
#     CuArray{T,N}(storage, size(texture))
# end

# Base.convert(::Type{CuPtr{T}}, buf::CUDA.Mem.ArrayBuffer{T}) where {T} = Base.convert(CuPtr{T}, UInt(pointer(buf)))
