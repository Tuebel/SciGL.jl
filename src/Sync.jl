# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
using GLAbstraction
using GLFW

"""
    RenderId
For rendering the to the correct tile id in `sync_render`
"""
struct RenderId
    id::Int64
    fn::Base.Callable
end

"""
    sync_render!(context, tiles, callback)
Synchronizes render calls via the returned `Channel` from several Threads to avoid parallel access to the OpenGL driver.

**Assumes** that n_tiles render calls are dispatched in parallel each with a unique ID each.
After each render call, the result must be awaited by each of the tasks.
When all render tasks have finished the returned `Condition` is notified.
Before each render loop, all buffers are cleared.

A `callback` can be provided to execute synchronous code after each render call.
E.g. `() -> unsafe_copyto!(dst, src)` transfer the result of the render call to the CPU. 

**Important:** call this function in the main thread where the render context has been created!
"""
function sync_render!(tiles::Tiles, callback::Base.Callable)
    # Trigger read calls
    cond = Threads.Condition()
    # Channel synchronizes calls to OpenGL driver
    # Run in main thread, do not spawn!
    channel = Channel{RenderId}() do channel
        while isopen(channel)
            # Clear buffers to prevent stencil glitches
            activate_all(tiles)
            clear_buffers()
            # Render until all tiles are occupied
            for _ in 1:length(tiles)
                render = take!(channel)
                activate_tile(tiles, render.id)
                render.fn()
            end
            # Condition pattern https://docs.julialang.org/en/v1/base/multi-threading/#Synchronization
            lock(cond)
            try
                # Allow synchronized operation after rendering
                callback()
                notify(cond)
            finally
                unlock(cond)
            end
        end
    end
    channel, cond
end

# draw and view_tile implement the dispatch and wait pattern for sync_render

"""
    draw(program, scene_object, channel, id)
Draws the whole scene via the given shader Program.
Transfers all the unions (matrices) to the shader Program.
"""
function draw(program::GLAbstraction.AbstractProgram, scene::Scene, channel::Channel, id::Integer)
    render_fn() = begin
        draw(program, scene)
    end
    put!(channel, RenderId(id, render_fn))
end

"""
    view_tile(M, tiles, id, cond)
Meant for use with the `Conditioned` returned from `sync_render`.
Blocks until the rendering has finished and then returns the view of the rendered image
Create a view of the Matrix `M` for the given tile id.
"""
function view_tile(M::AbstractMatrix, tiles::Tiles, id::Int, cond::Threads.Condition)
    lock(cond)
    try
        wait(cond)
        view_tile(M, tiles, id)
    finally
        unlock(cond)
    end
end