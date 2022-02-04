# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
using GLAbstraction
using GLFW

"""
    render_channel()
Synchronize the rendering by scheduling all render tasks on a single thread.
Call this function form the main thread!
"""
render_channel() =
    Channel{Task}() do channel
        while isopen(channel)
            task = take!(channel)
            schedule(task)
            wait(task)
        end
    end

draw_to_cpu_task(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer) =
    Task() do
        clear_buffers()
        draw(program, scene)
        gpu_data(framebuffer, 1)
    end

draw_to_cpu_async(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}) = put!(channel, draw_to_cpu_task(program, scene, framebuffer))

draw_to_cpu_sync(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}) = fetch(draw_to_cpu_async(program, scene, framebuffer, channel))




"""
    TypedFuture
Allows an asynchronous / decentralized workflow for dispatching a function on another task.
The value needs to have the correct size to allow copy!
"""
struct TypedFuture{T}
    condition::Threads.Condition
    fn::Base.Callable
    value::T
end

TypedFuture(fn, value) = TypedFuture(Threads.Condition(), fn, value)

Base.lock(future::TypedFuture) = lock(future.condition)
Base.unlock(future::TypedFuture) = unlock(future.condition)

Base.notify(future::TypedFuture) = notify(future.condition)
Base.wait(future::TypedFuture) = wait(future.condition)

function Base.fetch(future::TypedFuture)
    lock(future)
    try
        wait(future)
        future.value
    finally
        unlock(future)
    end
end

function Base.put!(future::TypedFuture, v)
    # Pattern: https://docs.julialang.org/en/v1/base/multi-threading/#Base.Threads.Condition
    lock(future)
    try
        copy!(future.value, v)
        notify(future)
    finally
        unlock(future)
    end
end

run(future::TypedFuture) = future.fn()

# TODO
# My guess is that it performs worse than the single worker since all Tasks are forced to wait for the other ones.
# In the former implementation each chain can run at its own pace.
# Moreover this implementation has the disadvantage of Assuming exactly n_tiles tasks which have to follow a strict pattern to avoid deadlocks.

# Channel synchronizes calls to OpenGL driver
# Run in main thread, do not spawn!
function render_channel(tiles::Tiles, framebuffer::GLAbstraction.FrameBuffer)
    cpu_data = gpu_data(framebuffer, 1)
    T_val = typeof(cpu_data)
    Channel{TypedFuture{T_val}}() do channel
        futures = Vector{TypedFuture{T_val}}(undef, length(tiles))
        while isopen(channel)
            # Render until all tiles are occupied
            for i in 1:length(tiles)
                activate_tile(tiles, i)
                # TODO Clear all causes weird glitches
                clear_buffers()
                future = take!(channel)
                futures[i] = future
                run(future)
            end
            # Fill the futures with data
            unsafe_copyto!(cpu_data, framebuffer.attachments[1])
            for i in 1:length(tiles)
                img = view_tile(cpu_data, tiles, i)
                put!(futures[i], img)
            end
        end
    end
end

# draw and view_tile implement the dispatch and wait pattern for sync_render
function draw_to_cpu_tiles(program::GLAbstraction.AbstractProgram, scene::Scene, channel::Channel{TypedFuture{T}}, render_size) where {T<:AbstractMatrix}
    render_fn() = begin
        draw(program, scene)
    end
    # The channel takes care of transferring the data to the TypedFuture
    future = TypedFuture(render_fn, T(undef, render_size...))
    put!(channel, future)
    fetch(future)
end
