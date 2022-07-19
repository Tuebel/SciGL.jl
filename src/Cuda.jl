# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.
using CUDA:
    CU_GRAPHICS_REGISTER_FLAGS_NONE,
    CU_GRAPHICS_REGISTER_FLAGS_READ_ONLY,
    CU_GRAPHICS_REGISTER_FLAGS_TEXTURE_GATHER,
    CU_RESOURCE_TYPE_ARRAY,
    CuArrayPtr,
    cuGraphicsGLRegisterImage,
    cuGraphicsMapResources,
    CUgraphicsResource,
    cuGraphicsSubResourceGetMappedArray,
    Mem

"""
    PersistentBuffer
Link an OpenGL (pixel) buffer object to an (Cu)Array by calling (Cu)Array(::PersistentBuffer, dims) once.
Transfer the data to the PersistentBuffer using `unsafe_copyto!` and the array will have the same contents since it points to the same linear memory.
Use `async_copyto` which returns immediately if you have other calculations to do while the transfer is in progress.
However you will have to manually synchronize the transfer by calling `sync_buffer`.
"""
mutable struct PersistentBuffer{T,N}
    id::GLuint
    dims::Dims{N}
    buffertype::GLenum
    flags::GLenum
    context::GLAbstraction.Context
    # Might change during async_copyto! + finalizer, thus mutable
    fence::GLsync

    function PersistentBuffer{T}(id::GLuint, dims::Dims{N}, buffertype::GLenum, flags::GLenum, context::GLAbstraction.Context, fence::GLsync) where {T,N}
        obj = new{T,N}(id, dims, buffertype, flags, context, fence)
        finalizer(GLAbstraction.free!, obj)
        obj
    end
end

"""
    PersistentBuffer(::Type{T}, dims; [buffertype=GL_PIXEL_PACK_BUFFER, FLAGS=GL_MAP_READ_BIT])
Generate a persistent OpenGL buffer object which can be mapped persistently to one Array /orCuArray.
Defaults to a pixel pack buffer for reading from an texture.
Set GL_MAP_READ_BIT or GL_MAP_WRITE_BIT as flags, `GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT` is always applied for persistent storage.
"""
function PersistentBuffer(::Type{T}, dims::Dims{N}; buffertype=GL_PIXEL_PACK_BUFFER, flags=GL_MAP_READ_BIT) where {T,N}
    id = glGenBuffers()
    persistent_flags = flags | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT
    glBindBuffer(buffertype, id)
    # WARN glNamedBufferStorage results in crashes when mapping?
    glBufferStorage(buffertype, prod(dims) * sizeof(T), C_NULL, persistent_flags)
    glBindBuffer(buffertype, 0)
    PersistentBuffer{T}(id, dims, buffertype, persistent_flags, GLAbstraction.current_context(), C_NULL)
end

"""
    PersistentBuffer(T, texture; [buffertype=GL_PIXEL_PACK_BUFFER, flags=GL_MAP_READ_BIT])
Convenience method to generate a persistent buffer object which can hold the elements of the texture.
This method allows to set a custom element type for the buffer which must be compatible with the texture element type, e.g. Float32 instead of Gray{Float32}
"""
PersistentBuffer(::Type{T}, texture::GLAbstraction.Texture; buffertype=GL_PIXEL_PACK_BUFFER, flags=GL_MAP_READ_BIT) where {T} = PersistentBuffer(T, size(texture); buffertype=buffertype, flags=flags)

"""
    PersistentBuffer(T, texture; [buffertype=GL_PIXEL_PACK_BUFFER, flags=GL_MAP_READ_BIT])
Convenience method to generate a persistent buffer object which can hold the elements of the texture.
This method sets the buffer element type to the element type of the texture.
"""
PersistentBuffer(texture::GLAbstraction.Texture{T}; buffertype=GL_PIXEL_PACK_BUFFER, flags=GL_MAP_READ_BIT) where {T} = PersistentBuffer(T, texture; buffertype=buffertype, flags=flags)

function GLAbstraction.free!(x::PersistentBuffer)
    glDeleteSync(x.fence)
    GLAbstraction.context_command(x.context, () -> glDeleteBuffers(1, [x.id]))
end

Base.size(buffer::PersistentBuffer) = buffer.dims
Base.length(buffer::PersistentBuffer) = prod(size(buffer))
Base.sizeof(buffer::PersistentBuffer{T}) where {T} = length(buffer) * sizeof(T)

GLAbstraction.bind(buffer::PersistentBuffer) = glBindBuffer(buffer.buffertype, buffer.id)
GLAbstraction.unbind(buffer::PersistentBuffer) = glBindBuffer(buffer.buffertype, 0)

is_readonly(buffer) = (buffer.flags & GL_MAP_READ_BIT == GL_MAP_READ_BIT) && (buffer.flags & GL_MAP_WRITE_BIT != GL_MAP_WRITE_BIT)

# OpenGL internal mapping from texture to buffer

"""
    unsafe_copyto!(buffer, source, dims...)
Synchronously transfer data from a source to the internal OpenGL buffer object.
For the best performance it is advised, to use a second buffer object and go the async route: http://www.songho.ca/opengl/gl_pbo.html
"""
function Base.unsafe_copyto!(buffer::PersistentBuffer, source, dims...)
    async_copyto!(buffer, source, GLsizei.(dims)...)
    sync_buffer(buffer)
end

"""
    sync_buffer(buffer)
Synchronizes to CUDA / CPU by mapping and unmapping the internal resource.
`dims`: (x_offset, y_offset, z_offset, width, height, depth), (width, height, depth) or (), zero offset is used if no custom offset is specified. 
"""
function sync_buffer(buffer::PersistentBuffer, timeout_ns=1)
    loop = true
    while loop
        res = glClientWaitSync(buffer.fence, GL_SYNC_FLUSH_COMMANDS_BIT, timeout_ns)
        if res == GL_ALREADY_SIGNALED || res == GL_CONDITION_SATISFIED
            loop = false
        elseif res == GL_WAIT_FAILED
            @error "Failed to sync the PersistentBuffer id: $(buffer.id)"
            loop = false
        end
    end
end

"""
    async_copyto!(dest, src, x_offset, y_offset, z_offset, width, height, depth)
Start the async transfer operation from a source to the internal OpenGL buffer object.
Call `sync_buffer` to finish the transfer operation by mapping & unmapping the buffer.
"""
function async_copyto!(dest::PersistentBuffer{T}, src::GLAbstraction.Texture, x_offset::GLint, y_offset::GLint, z_offset::GLint, width::GLsizei, height::GLsizei, depth::GLsizei) where {T}
    GLAbstraction.bind(dest)
    glGetTextureSubImage(src.id, 0, x_offset, y_offset, z_offset, width, height, depth, src.format, src.pixeltype, GLsizei(length(dest) * sizeof(T)), C_NULL)
    GLAbstraction.unbind(dest)
    # Synchronize after pixel transfer
    glDeleteSync(dest.fence)
    dest.fence = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
end

"""
    async_copyto!(dest, src, width, height, depth)
Start the async transfer operation from a source to the internal OpenGL buffer object.
Call `sync_buffer` to finish the transfer operation by mapping & unmapping the buffer.
Defaults to copying the texture with zero offset and the given width, height and depth.
"""
async_copyto!(dest::PersistentBuffer, src::GLAbstraction.Texture, width::GLsizei, height::GLsizei, depth::GLsizei) = async_copyto!(dest, src, GLint(0), GLint(0), GLint(0), width, height, depth)
# 2D and 1D
async_copyto!(dest::PersistentBuffer, src::GLAbstraction.Texture, width::GLsizei, height::GLsizei) = async_copyto!(dest, src, GLint(0), GLint(0), GLint(0), width, height, GLint(1))
async_copyto!(dest::PersistentBuffer, src::GLAbstraction.Texture, width::GLsizei) = async_copyto!(dest, src, GLint(0), GLint(0), GLint(0), width, GLint(1), GLint(1))


"""
    async_copyto!(dest, src)
Start the async transfer operation from a source to the internal OpenGL buffer object.
Call `sync_buffer` to finish the transfer operation by mapping & unmapping the buffer.
Defaults to copying the whole texture.
"""
async_copyto!(dest::PersistentBuffer, src::GLAbstraction.Texture) = async_copyto!(dest, src, GLsizei.(size(src))...)

"""
    async_copyto!(dest, src, dims...)
Start the async transfer operation from a source to the internal OpenGL buffer object.
Call `sync_buffer` to finish the transfer operation by mapping & unmapping the buffer.
`dims`: (x_offset, y_offset, z_offset, width, height, depth), (width, height, depth) or (), zero offset is used if no custom offset is specified. 
"""
async_copyto!(dest::PersistentBuffer, src::GLAbstraction.FrameBuffer, dims...) = async_copyto!(dest, first(src.attachments), dims...)

# CUDA mapping

"""
    CuArray(::PersistentBuffer)
Maps the OpenGL buffer to a CuArray
The internal CuPtr should stays the same, so it has to be called only once.
"""
function CUDA.CuArray(buffer::PersistentBuffer{T}) where {T}
    # Fetch the CUDA resource for it
    resource = Ref{CUgraphicsResource}()
    if is_readonly(buffer)
        flags = CU_GRAPHICS_REGISTER_FLAGS_READ_ONLY
    else
        flags = CU_GRAPHICS_REGISTER_FLAGS_NONE
    end
    CUDA.cuGraphicsGLRegisterBuffer(resource, buffer.id, flags)
    CUDA.cuGraphicsMapResources(1, resource, C_NULL)
    # Get the CuPtr to the buffer object
    cu_device_ptr = Ref{CUDA.CUdeviceptr}()
    num_bytes = Ref{Csize_t}()
    # dereference resource via []
    CUDA.cuGraphicsResourceGetMappedPointer_v2(cu_device_ptr, num_bytes, resource[])
    cu_ptr = Base.unsafe_convert(CuPtr{T}, cu_device_ptr[])
    cu_array = unsafe_wrap(CuArray, cu_ptr, size(buffer))
    cu_array
end

# Regular CPU mapping

"""
    Array(::PersistentBuffer)
Maps the OpenGL buffer to a CuArray
The internal CuPtr should stays the same, so it has to be called only once.
"""
function Base.Array(buffer::PersistentBuffer{T}) where {T}
    # Avoid nullptr
    unmap_buffer(buffer)
    ptr = map_buffer(buffer)
    if (ptr == C_NULL)
        @error "Mapping PersistentBuffer id $(buffer.id) returned NULL"
        return zeros(T, dims)
    end
    unsafe_wrap(Array, ptr, size(buffer))
end

"""
    map_resource(buffer)
Map the internal resource to a CPU pointer.
"""
map_buffer(buffer::PersistentBuffer{T}) where {T} = is_readonly(buffer) ? Ptr{T}(glMapNamedBufferRange(buffer.id, 0, sizeof(buffer), buffer.flags)) : Ptr{T}(glMapNamedBufferRange(buffer.id, 0, sizeof(buffer), buffer.flags))

"""
    map_resource(buffer)
Unmap the internal for CPU use.
"""
unmap_buffer(buffer::PersistentBuffer) = glUnmapNamedBuffer(buffer.id)

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

Base.unsafe_copyto!(dest::AbstractArray, src::GLAbstraction.FrameBuffer) = unsafe_copyto!(dest, first(src.attachments))

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
