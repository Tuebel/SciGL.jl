# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using GLAbstraction
using GLFW

# Conclusion: Tiled rendering is about 1,5x faster than rendering into one texture but requires 6x more memory.
# Tiled rendering is also harder to implement, for the sake of simplicity I would recommend starting with the Task based approach.

# My guess is that the tiled renderer performs worse than the task based approach since all Tasks are forced to wait for the other ones.
# In the former implementation each chain can run at its own pace.
# Moreover this implementation has the disadvantage of Assuming exactly n_tiles tasks which have to follow a strict pattern to avoid deadlocks.

# Benchmarks surprisingly show that both perform equally well.
# All versions scale linearly with the number of tasks.
# So probably most time is spent on rendering and copying the data.

"""
    render_channel()
Synchronize the rendering by scheduling each render `Task` on a single thread.
This function has to be called from the same thread that the render context was created in.

Has the worst performance of the implementations with moderate memory usage.
"""
render_channel() =
    Channel{Task}() do channel
        while isopen(channel)
            task = take!(channel)
            schedule(task)
            wait(task)
        end
    end

################### Intel ##################################################
# BenchmarkTools.Trial: 1383 samples with 1 evaluation.
#  Range (min … max):  240.952 μs … 15.821 ms  ┊ GC (min … max): 0.00% … 44.91%
#  Time  (median):       3.417 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):     3.605 ms ±  1.724 ms  ┊ GC (mean ± σ):  0.88% ±  4.04%

#   ▇                ▃█▇▇▇▇▇▇▅▅▃▄▂▂▂▂▂▂▂▂▂  ▁                    ▁
#   █▄▆▁▆▆▅▅▆▆▅▇▆▆▆████████████████████████▇█▇█▆▇▆█▆▆██▇▆▆▁▇▆▅▆▆ █
#   241 μs        Histogram: log(frequency) by time      8.84 ms <

#  Memory estimate: 65.04 KiB, allocs estimate: 238.

################### NVIDIA ##################################################
# BenchmarkTools.Trial: 1886 samples with 1 evaluation.
#  Range (min … max):  241.148 μs … 14.087 ms  ┊ GC (min … max): 0.00% … 35.59%
#  Time  (median):       1.909 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):     2.645 ms ±  2.073 ms  ┊ GC (mean ± σ):  1.89% ±  6.53%

#         ▄▇█▆▄▁   ▁▂▁      ▂                 ▁▁                  
#   ▃▃▃▅▄▆██████▇▅▇████▆▁▃▅███▆▅▁▁▁▅▄▁▅▅▃▄▁▁▁▆██▆▅▃▄▁▁▁▅▃▃▁▁▁▃▇▇ █
#   241 μs        Histogram: log(frequency) by time        12 ms <

#  Memory estimate: 145.12 KiB, allocs estimate: 284.

draw_to_cpu_task(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer) =
    Task() do
        clear_buffers()
        draw(program, scene)
        gpu_data(framebuffer, 1)
    end

draw_to_cpu_async(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}) = put!(channel, draw_to_cpu_task(program, scene, framebuffer))

draw_to_cpu(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}) = fetch(draw_to_cpu_async(program, scene, framebuffer, channel))

################### Intel ##################################################
# BenchmarkTools.Trial: 1129 samples with 1 evaluation.
#  Range (min … max):  203.266 μs … 66.146 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):       3.839 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):     4.414 ms ±  3.044 ms  ┊ GC (mean ± σ):  0.77% ± 4.01%

#                 ▆▂█▄▃▄▁                                         
#   █▁▁▂▁▁▂▂▁▂▂▃▃▇███████▆▅▅▄▄▄▄▄▂▂▂▃▂▃▂▃▂▂▂▁▂▂▂▂▂▂▂▁▁▂▁▂▂▁▁▁▁▁▁ ▃
#   203 μs          Histogram: frequency by time         11.9 ms <

#  Memory estimate: 25.91 KiB, allocs estimate: 235.

################### NVIDIA ##################################################
# BenchmarkTools.Trial: 2049 samples with 1 evaluation.
#  Range (min … max):  428.400 μs … 18.156 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):       1.868 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):     2.432 ms ±  1.672 ms  ┊ GC (mean ± σ):  1.48% ± 5.24%

#          ▁▆▇██▆▄▂       ▂▂          ▂▂                  ▁▁▁    ▁
#   ▅▅▆▆▄▆▇█████████▅▆▅▆▆█████▅▅▅▄▁▅▇▇███▇▅▄▄▁▄▆▄▄▁▄▄▅▁▅▆▇███▇▅▅ █
#   428 μs        Histogram: log(frequency) by time      8.17 ms <

#  Memory estimate: 104.11 KiB, allocs estimate: 245.

draw_to_cpu_task(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, cpu_data::AbstractMatrix) =
    Task() do
        clear_buffers()
        draw(program, scene)
        unsafe_copyto!(cpu_data, framebuffer.attachments[1])
        cpu_data
    end

draw_to_cpu_async(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}, cpu_data::AbstractMatrix) = put!(channel, draw_to_cpu_task(program, scene, framebuffer, cpu_data))

draw_to_cpu(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}, cpu_data::AbstractMatrix) = fetch(draw_to_cpu_async(program, scene, framebuffer, channel, cpu_data))

################### Intel ##################################################
# BenchmarkTools.Trial: 2265 samples with 1 evaluation.
#  Range (min … max):  1.175 ms … 23.866 ms  ┊ GC (min … max): 0.00% … 84.18%
#  Time  (median):     2.040 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   2.197 ms ±  1.302 ms  ┊ GC (mean ± σ):  1.63% ±  4.74%

#     ▂▅█▇▅▄▅█▇▅▄▃▃▁                                           ▁
#   ▇█████████████████▆▆▆▆▅▆▇▄▇▇▅▆▆▅▇▇▇█▇█▇▇▄▅▄▆▅▆▁▅▁▁▆▁▄▁▁▅▄▆ █
#   1.17 ms      Histogram: log(frequency) by time      6.6 ms <

#  Memory estimate: 210.88 KiB, allocs estimate: 675.

################### NVIDIA ##################################################
# BenchmarkTools.Trial: 2789 samples with 1 evaluation.
#  Range (min … max):  1.081 ms … 152.901 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     1.587 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   1.783 ms ±   3.048 ms  ┊ GC (mean ± σ):  2.00% ± 6.08%

#      ▇▇█▆▂▂                                                    
#   ▃▄███████▆▃▃▂▂▂▂▂▂▁▂▂▁▂▂▂▂▂▂▂▂▁▂▂▁▁▂▂▂▂▂▁▂▂▂▁▂▂▁▂▂▂▁▁▂▂▁▁▁▂ ▃
#   1.08 ms         Histogram: frequency by time        6.39 ms <

#  Memory estimate: 665.08 KiB, allocs estimate: 963.

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

"""
    render_channel()
Synchronize the rendering by scheduling each `TypedFuture` on a single thread.
Uses tiled rendering to transfer the data into a preallocated array.
This function has to be called from the same thread that the render context was created in.

Has the best performance of the implementations with high memory usage.
"""
function render_channel(tiles::Tiles, framebuffer::GLAbstraction.FrameBuffer)
    cpu_data = gpu_data(framebuffer, 1)
    T_val = typeof(cpu_data)
    Channel{TypedFuture{T_val}}() do channel
        futures = Vector{TypedFuture{T_val}}(undef, length(tiles))
        while isopen(channel)
            # Render until all tiles are occupied
            for i in 1:length(tiles)
                activate_tile(tiles, i)
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
function draw_to_cpu(program::GLAbstraction.AbstractProgram, scene::Scene, channel::Channel{TypedFuture{T}}, render_size) where {T<:AbstractMatrix}
    render_fn() = begin
        draw(program, scene)
    end
    # The channel takes care of transferring the data to the TypedFuture
    future = TypedFuture(render_fn, T(undef, render_size...))
    put!(channel, future)
    fetch(future)
end
