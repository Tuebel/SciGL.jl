# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2023, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

"""
    OffscreenContext
Keep everything required for offscreen rendering and transfer to a `(Cu)Array` in one place.
Also uses Julia image conventions so the returned data layout is (y,x,z) vs. (x,y,z).

**High level API** `draw(context, scenes...)`: Synchronously draws and transfers the scenes to the `(Cu)Array`.
During construction the context's framebuffer is bound once. Make sure to bind it again if you unbind it.

**Low level API** might be useful if you have calculations to execute during the transfer:
* `draw_framebuffer` draws a scene to the texture attachment of the `framebuffer`
* `start_transfer` to asynchronously transfer `framebuffer` → `gl_buffer` / `render_data`
* `wait_transfer` to wait for the transfer to finish
* Create a view via `@view render_data[:, :, 1:n_images]` which now contains the n_images renderings.
"""
struct OffscreenContext{T,F<:GLAbstraction.FrameBuffer,C<:AbstractArray{T},P<:GLAbstraction.AbstractProgram}
    window::GLFW.Window
    # Preallocate a CPU Array or GPU CuArray, this also avoids having to pass a device flag
    framebuffer::F
    gl_buffer::PersistentBuffer{T}
    render_data::C
    shader_program::P
end


"""
    color_offscreen_context(width, height, [depth=1, array_type=Array, shaders=(SimpleVert, NormalFrag)])
Simplified generation of an OpenGL context for rendering images of a specific size.
Batched rendering is enabled by generating a 3D Texture of RGBA pixels with size (width, height, depth).
Specify the `array_type` as `Array` or `CuArray`.
"""
function color_offscreen_context(width::Integer, height::Integer, depth::Integer=1, ::Type{T}=Array, shaders=(SimpleVert, NormalFrag)) where {T}
    window = context_offscreen(width, height)
    # Do not use RBO which only supports 2D shapes.
    framebuffer = color_framebuffer(width, height, depth)
    GLAbstraction.bind(framebuffer)
    texture = first(GLAbstraction.color_attachments(framebuffer))
    gl_buffer = PersistentBuffer(texture)
    render_data = T(gl_buffer)
    program = GLAbstraction.Program(shaders...)
    OffscreenContext(window, framebuffer, gl_buffer, render_data, program)
end

"""
    depth_offscreen_context(width, height, [depth=1, array_type=Array])
Simplified generation of an OpenGL context for rendering depth images of a specific size.
Batched rendering is enabled by generating a 3D Texture of Float32 with size (width, height, depth).
Specify the `array_type` as `Array` or `CuArray`.

The resulting `OffscreenContext`'s `render_data` has the `array_type{Float32}` which allows seamless transfer from the depth texture. 
"""
function depth_offscreen_context(width::Integer, height::Integer, depth::Integer=1, ::Type{T}=Array) where {T}
    window = context_offscreen(width, height)
    # Do not use RBO which only supports 2D shapes.
    framebuffer = depth_framebuffer(width, height, depth)
    GLAbstraction.bind(framebuffer)
    texture = first(GLAbstraction.color_attachments(framebuffer))
    gl_buffer = PersistentBuffer(texture)
    render_data = T(gl_buffer)
    program = GLAbstraction.Program(SimpleVert, DepthFrag)
    OffscreenContext(window, framebuffer, gl_buffer, render_data, program)
end

# Forward methods
destroy_context(context::OffscreenContext) = destroy_context(context.window)
upload_mesh(context::OffscreenContext, mesh_file::AbstractString) = upload_mesh(context.shader_program, mesh_file)
upload_mesh(context::OffscreenContext, mesh::Mesh) = upload_mesh(context.shader_program, mesh)

# Base methods
Base.show(io::IO, context::OffscreenContext{T}) where {T} = print(io, "OffscreenContext{$(T)}\n$(context.framebuffer)\nRender Data: $(typeof(context.render_data))")
Base.size(render_context::OffscreenContext) = size(render_context.render_data)
Base.eltype(::OffscreenContext{T}) where {T} = T

"""
    draw(context, scenes)
Synchronously draw the scenes into the layers of the contxt's framebuffer and transfer it to the render_data of the context.
Returns a view of of size (width, height, length(scenes)).

WARN: Overwrites the data in the context, copy it if you need it to persist!
"""
function draw(context::OffscreenContext, scenes::AbstractArray{<:Scene})
    for (idx, scene) in enumerate(scenes)
        draw_framebuffer(context, scene, idx)
    end
    transfer(context, length(scenes))
end

"""
    draw(context, scene)
Synchronously transfer the image with the given `depth` from OpenGL to the `render_data`.
Returns a view of of size (width, height).
"""
function draw(context::OffscreenContext, scene::Scene)
    draw_framebuffer(context, scene)
    transfer(context)
end

"""
    draw_framebuffer(context, scene, [layer_id=1])
Render the scene to the framebuffer of the context.
"""
function draw_framebuffer(context::OffscreenContext, scene::Scene, layer_id=1::Integer)
    # Draw to framebuffer
    activate_layer(context.framebuffer, layer_id)
    clear_buffers()
    draw(context.shader_program, scene)
end

"""
    transfer(context, [depth])
Synchronously transfer the image from OpenGL to the `render_data`.
Returns a view of of size (width, height, depth).

WARN: Overwrites the data in the context, copy it if you need it to persist!
"""
function transfer(context::OffscreenContext, depth)
    start_transfer(context, depth)
    wait_transfer(context)
    # Julia image convention is (y,x) vs. OpenGL (x,y)
    permuted = PermutedDimsArray(context.render_data, (2, 1, 3))
    @view permuted[:, :, 1:depth]
end

# TODO How to implement it with less copy and pasting?
function transfer(context::OffscreenContext)
    start_transfer(context)
    wait_transfer(context)
    # Julia image convention is (y,x) vs. OpenGL (x,y)
    permuted = PermutedDimsArray(context.render_data, (2, 1, 3))
    @view permuted[:, :, 1]
end

"""
    start_transfer(context, [depth=1])
Start the asynchronous transfer the image with the given `depth` from OpenGL to the `render_data`.

WARN: Overwrites the data in the context, copy it if you need it to persist!
"""
function start_transfer(context::OffscreenContext, depth=1)
    width, height = size(context.gl_buffer)
    async_copyto!(context.gl_buffer, context.framebuffer, width, height, depth)
end

"""
    start_transfer(context, [timeout_ns=10])
Wait for the transfer started in `start_transfer` to finish.
Allows to set the timeout in nanoseconds of the `glClientWaitSync` call in the sync loop.
"""
wait_transfer(context::OffscreenContext, timeout_ns=1) = sync_buffer(context.gl_buffer, timeout_ns)
