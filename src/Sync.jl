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

################### Intel ##################################################
# BenchmarkTools.Trial: 1321 samples with 1 evaluation.
#  Range (min … max):  445.771 μs … 14.892 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):       3.477 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):     3.778 ms ±  1.147 ms  ┊ GC (mean ± σ):  1.40% ± 5.78%

#                     ▃▅█▄▃▃▂▂                                    
#   ▂▁▁▁▁▁▂▁▁▂▂▂▂▂▁▂▂▇█████████▆▄▅▃▄▃▄▃▃▄▃▃▂▃▂▂▂▂▂▂▂▂▂▃▂▂▂▂▂▂▁▁▂ ▃
#   446 μs          Histogram: frequency by time         8.43 ms <

#  Memory estimate: 143.28 KiB, allocs estimate: 249.

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

draw_to_cpu_sync(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}) = fetch(draw_to_cpu_async(program, scene, framebuffer, channel))

################### Intel ##################################################
# BenchmarkTools.Trial: 1323 samples with 1 evaluation.
#  Range (min … max):  429.025 μs …  12.084 ms  ┊ GC (min … max): 0.00% … 60.45%
#  Time  (median):       3.525 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):     3.773 ms ± 991.107 μs  ┊ GC (mean ± σ):  0.91% ±  4.67%

#                        █▇▄▄▁▂▁                                   
#   ▂▁▁▁▁▁▁▁▁▁▁▂▂▂▂▂▂▃▅▆████████▇▅▄▃▃▄▄▄▄▄▃▃▃▂▂▂▂▂▂▂▂▂▂▂▁▁▂▁▁▁▁▂▂ ▃
#   429 μs           Histogram: frequency by time         8.16 ms <

#  Memory estimate: 104.17 KiB, allocs estimate: 247.

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

draw_to_cpu_sync(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel{Task}, cpu_data::AbstractMatrix) = fetch(draw_to_cpu_async(program, scene, framebuffer, channel, cpu_data))

################### Intel ##################################################
# BenchmarkTools.Trial: 1846 samples with 1 evaluation.
#  Range (min … max):  1.359 ms … 15.559 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     2.474 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   2.689 ms ±  1.066 ms  ┊ GC (mean ± σ):  1.49% ± 5.42%

#       ▁▂ ▆▃▂▅█▆▂▁ ▁                                           
#   ▂▂▃▄█████████████▇▆▅▄▄▄▃▂▂▃▃▃▃▃▃▃▃▃▃▁▂▂▂▃▂▂▁▂▂▂▂▁▁▁▂▁▂▁▁▂▂ ▄
#   1.36 ms        Histogram: frequency by time        6.82 ms <

#  Memory estimate: 630.16 KiB, allocs estimate: 910.

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

# My guess is that it performs worse than the single worker since all Tasks are forced to wait for the other ones.
# In the former implementation each chain can run at its own pace.
# Moreover this implementation has the disadvantage of Assuming exactly n_tiles tasks which have to follow a strict pattern to avoid deadlocks.

# Benchmarks surprisingly show that both perform equally well.
# The former version is marginally fast (~5%).
# Both versions scale linearly with the number of tasks.
# So my guess is that most time is spent on copying the data.

# For large amounts of threads, the latter version uses only ~50% of the memory with 3x less allocations.
# With small texture sizes and many threads, it is also ~50% faster.

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
