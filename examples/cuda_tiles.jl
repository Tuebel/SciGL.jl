# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using BenchmarkTools
using CUDA
using SciGL

const N_TASKS = 500
const WIDTH = 100
const HEIGHT = 100

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)
tiles = Tiles(N_TASKS, WIDTH, HEIGHT)
# On Intel copying data from a texture or an RBO does not really make a difference
framebuffer = depth_framebuffer(size(tiles)...)
GLAbstraction.bind(framebuffer)
enable_depth_stencil()
set_clear_color()

# Compile shader program
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)
# Init scene
monkey = load_mesh(depth_prog, "examples/meshes/monkey.obj")
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> Camera
scene = Scene(camera, [monkey, monkey])
scene = @set scene.camera.pose.translation = Translation(1.5, 0, 1.5)
scene = @set scene.camera.pose.rotation = lookat(scene.camera, scene.meshes[1], [0 1 0])
scenes = fill(scene, N_TASKS)

"""
    gpu_block_sum(tex, tiles, out)
Calculates the sum of each tile in `tex`.
For tiles of length N choose block_size=N, length(out)=N.
The shared memory must have n_threads * sizeof(T) bytes.
"""
function gpu_block_sum(tex::CuDeviceTexture{<:Any,2}, tiles::Tiles, out::CuDeviceVector{T}, fn) where {T}
    # aliases for readability
    thread_id = threadIdx().x
    block_id = blockIdx().x
    n_threads = blockDim().x
    # Thread local accumulation
    thread_sum = zero(T)
    # thread strided loop
    for i in thread_id:n_threads:tile_length(tiles)
        # Texture indices: N-Dims Float32
        x, y = tile_coordinates(tiles, block_id, i) .|> Float32
        @inbounds thread_sum += fn(tex[x, y])
    end
    # Synchronized accumulation for block
    thread_sums = CuDynamicSharedArray(Float32, n_threads)
    @inbounds thread_sums[thread_id] = thread_sum
    sync_threads()
    if thread_id == 1
        @inbounds out[block_id] = sum(thread_sums)
    end
    return nothing
end

function cuda_evaluation(tex::GLAbstraction.Texture, tiles; n_threads=256)
    # TODO Calculate optimal threads?
    cu_tex = CuTexture(Float32, tex)
    n_blocks = length(tiles)
    out = CuVector{Float64}(undef, n_blocks)
    shmem_size = n_threads * sizeof(eltype(out))
    @cuda threads = n_threads blocks = n_blocks shmem = shmem_size gpu_block_sum(cu_tex, tiles, out, exp)
    Array(out)
end

function bench_serial(program, scenes, framebuffer, tiles)
    # Draw the tiles
    GLAbstraction.bind(framebuffer)
    activate_all(tiles::Tiles)
    clear_buffers()
    for (i, scene) in enumerate(scenes)
        activate_tile(tiles, i)
        draw(program, scene)
    end
    # CUDA calculations
    texture = framebuffer.attachments[1]
    # sums = cuda_evaluation(texture, tiles)
    nothing
end

# TODO how to provide a new measurement in each loop?
function my_channel(framebuffer::GLAbstraction.FrameBuffer, tiles::Tiles)
    Channel{SciGL.TypedFuture{Vector{Float64}}}() do channel
        futures = Vector{SciGL.TypedFuture{Vector{Float64}}}(undef, length(tiles))
        while isopen(channel)
            # Render phase
            for i in 1:length(tiles)
                activate_tile(tiles, i)
                future = take!(channel)
                futures[i] = future
                run(future)
            end
            # Calculation phase
            texture = framebuffer.attachments[1]
            sums = cuda_evaluation(texture, tiles)
            # Return phase
            for (i, future) in enumerate(futures)
                put!(future, sums[i])
            end
        end
    end
end

# This is where the magic happens 
channel = my_channel(framebuffer, tiles)

function bench_parallel(program, scenes, framebuffer, tiles, channel::Channel{SciGL.TypedFuture{T}}) where {T}
    # Draw the tiles
    GLAbstraction.bind(framebuffer)
    for scene in scenes
        render_fn() = begin
            draw(program, scene)
        end
        future = SciGL.TypedFuture(render_fn, T(undef, 1))
        put!(channel, future)
        Threads.@spawn fetch(future)
    end
    nothing
end

@benchmark bench_serial(depth_prog, scenes, framebuffer, tiles)
@benchmark @sync bench_parallel(depth_prog, scenes, framebuffer, tiles, channel)

# For large sample number much faster, up to 8x on my laptop (30ms for 1000 samples) compared to only one scene per texture (cuda_tasks)
# I guess bench_parallel is a bit slower because of overhead of spawning the thread.
# Moreover a correct implementation and debugging is much more involved...
# TODO does it make sense for massively parallel chains which use threads or only for PG?
# TODO should I implement my own MCMCThreads? The Threads.@threads would deadlock anyways.

function parallel_predict(scenes::AbstractVector{<:Scene})
    result = Vector{Scene}(undef, length(scenes))
    Threads.@threads for i = 1:length(scenes)
        r = rand()
        scene = scenes[i]
        scene = @set scene.camera.pose.translation = Translation(1.5 * sin(2 * π * r / 5), 0, 1.5 * cos(2 * π * r / 5))
        result[i] = @set scene.camera.pose.rotation = lookat(scene.camera, scene.meshes[1], [0 1 0])
    end
    result
end

function serial_predict(scenes::AbstractVector{<:Scene})
    result = Vector{Scene}(undef, length(scenes))
    for i = 1:length(scenes)
        r = rand()
        scene = scenes[i]
        scene = @set scene.camera.pose.translation = Translation(1.5 * sin(2 * π * r / 5), 0, 1.5 * cos(2 * π * r / 5))
        result[i] = @set scene.camera.pose.rotation = lookat(scene.camera, scene.meshes[1], [0 1 0])
    end
    result
end

# Only makes sense for large number of parallel samples, on my machine > 25
# @benchmark parallel_predict(scenes)
# @benchmark serial_predict(scenes)

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
