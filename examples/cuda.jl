# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using BenchmarkTools
using CUDA
using SciGL

const WIDTH = 2000
const HEIGHT = 2000

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)
# On Intel copying data from a texture or an RBO does not really make a difference
framebuffer = depth_framebuffer(WIDTH, HEIGHT)
texture = framebuffer.attachments[1]

# Compile shader program
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)
# Init mesh
monkey = load_mesh(depth_prog, "examples/meshes/monkey.obj") |> SceneObject
# Init Camera
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject
camera = @set camera.pose.translation = Translation(1.3 * sin(2 * π * time() / 5), 0, 1.3 * cos(2 * π * time() / 5))
# WARN if not using Scene, to_gpu has to be called for the camera
camera = @set camera.pose.rotation = lookat(camera, monkey, [0 1 0])
# Buffer settings
enable_depth_stencil()
set_clear_color()

# Draw to framebuffer
GLAbstraction.bind(framebuffer)
clear_buffers()
to_gpu(depth_prog, camera)

# Sanity check for persistent buffer
persistent_buf = PersistentBuffer(Float32, texture)
cu_sanity = CuArray(persistent_buf)
unsafe_copyto!(persistent_buf, texture)
@assert maximum(cu_sanity) == 0

draw(depth_prog, monkey)
unsafe_copyto!(persistent_buf, texture, 100, 100)
# Upper left corner should be blank
@assert maximum(cu_sanity) == 0
unsafe_copyto!(persistent_buf, texture)
@assert 0 < maximum(cu_sanity) < 2

# Fill undefined and then copy empty framebuffer -> should change
cu_array = CuArray{Float32}(undef, (WIDTH, HEIGHT))
cpu_data = Matrix{Float32}(undef, WIDTH, HEIGHT)

# Slowest
function broadcast_copy(cu_array, texture)
    cu_tex = CUDA.CuTexture(Float32, texture)
    cu_array .= cu_tex
end
@benchmark CUDA.@sync broadcast_copy(cu_array, texture)
# Maximum depth value should change for rotated monkey
@assert 0 < maximum(cu_array) < 2
#  Range (min … max):  1.722 ms …  14.447 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     2.078 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   2.181 ms ± 580.061 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%

# A bit faster might be due to globals
@benchmark CUDA.@sync unsafe_copyto!(cu_array, texture)
@assert 0 < maximum(cu_array) < 2
#  Range (min … max):  1.012 ms …  41.702 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     1.288 ms               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   1.330 ms ± 763.115 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%

# Even faster and more consistent times because of the persistent buffer. Would allow double buffering for optimization.😍 
@benchmark unsafe_copyto!(persistent_buf, texture)
@assert 0 < maximum(cu_sanity) < 2
#  Range (min … max):  1.014 ms …  1.163 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     1.019 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   1.025 ms ± 12.736 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%

# Copying only the required parts is MUCH FASTER
@benchmark unsafe_copyto!(persistent_buf, texture, 100, 100)
#  Range (min … max):  13.687 μs … 66.332 μs  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     16.458 μs              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   17.631 μs ±  4.065 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%

"""
    pixel_xy(width, iter)
Returns (x, y) coordinate in the texture for a grid-stride loop style iter.
Convention is taken form GLAbstraction → (width, height) and (x, y) indices.
"""
function texture_xy(tex_width::Integer, iter::Integer)
    # Convention from GLAbstraction: Matrix(width, height)
    x = mod(iter - 1, tex_width) + 1
    y = div(iter - 1, tex_width) + 1
    # Texture requires Float32 indices
    # Float32(x), Float32(y)
    x, y
end
likelihood_sum(μ, z) = μ + z
# Likelihood accumulator for textures to avoid copies
function block_sum(block_sums::CuDeviceVector{T}, tex::AbstractArray{Float32,2}) where {T}
    thread_id = threadIdx().x
    block_id = blockIdx().x
    n_threads = blockDim().x  # block local threads
    n_blocks = gridDim().x
    # grid-stride loop, stride = n_threads in grid
    index = (block_id - 1) * n_threads + thread_id
    stride = n_blocks * n_threads
    # width of the image
    width = size(tex, 1)
    # Thread local accumulation
    thread_sum = zero(T)
    for i = index:stride:length(tex)
        x, y = texture_xy(width, i)
        # WARN Texture indices: N-Dims Float32 https://github.com/JuliaGPU/CUDA.jl/blob/master/src/device/texture.jl#L87
        # TODO replay μ
        @inbounds thread_sum += exp(tex[x, y])
    end
    # Synchronized accumulation for block
    thread_sums = CuDynamicSharedArray(Float32, n_threads)
    @inbounds thread_sums[thread_id] = thread_sum
    sync_threads()
    if thread_id == 1
        @inbounds block_sums[block_id] = sum(thread_sums)
    end
    return nothing
end

THREADS = 128
BLOCKS = cld(length(texture), THREADS)
SHMEM = THREADS * sizeof(Float32)

cu_tex = CUDA.CuTexture(Float32, texture)
block_sums = CuVector{Float64}(undef, BLOCKS)

@cuda threads = THREADS blocks = BLOCKS shmem = SHMEM block_sum(block_sums, cu_array)

# WARN performance 1.5x better when manually setting the number of threads per block to 128 or 256 instead of using the scheme from the CUDA.jl docs

function bench_kernel(texture)
    THREADS = 128
    BLOCKS = cld(length(texture), THREADS)
    SHMEM = THREADS * sizeof(Float32)

    cu_tex = CUDA.CuTexture(Float32, texture)
    block_sums = CuVector{Float64}(undef, BLOCKS)

    @cuda threads = THREADS blocks = BLOCKS shmem = SHMEM block_sum(block_sums, cu_tex)
    Array(block_sums)
    nothing
end
function bench_array(texture)
    cu_array = CuMatrix{Float32}(undef, size(texture))
    unsafe_copyto!(cu_array, texture)
    cu_array = exp.(cu_array)
    CUDA.@sync sum(cu_array)
    nothing
end

bench_kernel(texture)
bench_array(texture)
@benchmark bench_kernel(texture)
@benchmark bench_array(texture)
@benchmark begin
    cpu_data = Float32.(gpu_data(texture))
    sum(cpu_data .+ 1)
end

# using ImageView
# M = Array(cu_array)
# imshow(M'[end:-1:begin, :])

# using Cthulhu
# @device_code_warntype interactive = true @cuda launch = false kernel_fn!(cu_array, cu_tex)

# function benchmark_tex_alloc()
#     CUDA.@sync texturea = CUDA.CuTexture(Float32, texture)
#     # cuarray .= tex
#     # sum(cuarray)
# end

# Avoiding transfers to the CPU is worth it 2x - 4x faster
# @benchmark CUDA.@sync CUDA.CuTexture(Float32, texture)
# BenchmarkTools.Trial: 10000 samples with 1 evaluation.
#  Range (min … max):  109.529 μs …   3.969 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     181.463 μs               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   288.054 μs ± 513.828 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%
#   ▁█▅▂                                                          ▁
#   █████▆▅▄▄▃▁▃▁▁▃▁▁▃▄▃▄▅▆▆▄▁▁▁▄▁▅▆▆▆▄▄▃▃▁▃▄▄▄▅▅▄▄▅▅▄▄▄▅▆▆▆▇▆▇▇▆ █
#   110 μs        Histogram: log(frequency) by time       3.33 ms <
#  Memory estimate: 1.33 KiB, allocs estimate: 23.

# @benchmark CUDA.@sync unsafe_copyto!(cuarray, texture)
# BenchmarkTools.Trial: 9456 samples with 1 evaluation.
#  Range (min … max):  303.778 μs …   5.949 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     324.243 μs               ┊ GC (median):    0.00%
#  Time  (mean ± σ):   522.485 μs ± 618.392 μs  ┊ GC (mean ± σ):  0.00% ± 0.00%
#   █▅▄▂                                                          ▁
#   █████▇▅▅▄▅▄▆▇█▇██▇▆▅▄▄▃▄▄▅▅▆▅▅▅▆▅▅▅▅▅▅▄▆▆▆▆▇▇▇▇▇█▆▆▆▅▆▅▄▅▂▅▆▅ █
#   304 μs        Histogram: log(frequency) by time       3.21 ms <
#  Memory estimate: 384 bytes, allocs estimate: 12.

# @benchmark unsafe_copyto!(cpu_data, texture)
# BenchmarkTools.Trial: 3789 samples with 1 evaluation.
#  Range (min … max):  852.988 μs … 7.121 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     947.129 μs             ┊ GC (median):    0.00%
#  Time  (mean ± σ):     1.309 ms ± 1.100 ms  ┊ GC (mean ± σ):  0.00% ± 0.00%
#   █▆▅▃▂                      ▁                                ▁
#   ██████▆▃▅▆▆▆▇█▆▇▆▆▅▆▆▃▅▁▄▄██▇▆▇▇▇▇▇▇▇▆▃▃▄▅▁▄▃▃▃▁▁▁▁▁▁▄▆▆█▇▇ █
#   853 μs       Histogram: log(frequency) by time      6.44 ms <
#  Memory estimate: 384 bytes, allocs estimate: 12.

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)