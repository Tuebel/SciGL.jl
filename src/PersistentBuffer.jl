# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

using CUDA:
    CU_GRAPHICS_REGISTER_FLAGS_NONE,
    CU_GRAPHICS_REGISTER_FLAGS_READ_ONLY,
    cuGraphicsMapResources,
    CUgraphicsResource,
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
async_copyto!(dest::PersistentBuffer, src::GLAbstraction.FrameBuffer, dims...) = async_copyto!(dest, first(GLAbstraction.color_attachments(src)), dims...)

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
