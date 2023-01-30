# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

# Lessons learned: Overhead of switching layers does exist but is compensated by not having to reindex the memory.
# Moreover, layered compared to reindexing does not allocate a second CuArray which will be helpful if we want to max out the samples per inference step  

using Accessors
using BenchmarkTools
using CUDA
using SciGL
using ImageView

const WIDTH = 100
const HEIGHT = 100
const N_TILES = 1000

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)

# Setup framebuffers
layer_framebuffer = color_framebuffer(WIDTH, HEIGHT, N_TILES)
tiles = Tiles(N_TILES, WIDTH, HEIGHT)
tile_framebuffer = color_framebuffer(size(tiles)...)

# Buffer settings
enable_depth_stencil()
set_clear_color()

# Compile shader program
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init scene
monkey = load_mesh(depth_prog, "examples/meshes/monkey.obj")
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> Camera
scene = SciGL.Scene(camera, [monkey, monkey])

# Benchmark overhead of switching layers

@benchmark begin
    GLAbstraction.bind(tile_framebuffer)
    activate_all(tiles)
    clear_buffers()
    for id in range(1, N_TILES)
        activate_tile(tiles, id)
        draw(depth_prog, scene)
    end
end

# BenchmarkTools.Trial: 122 samples with 1 evaluation.
#  Range (min … max):  35.023 ms … 73.273 ms  ┊ GC (min … max): 0.00% … 17.59%
#  Time  (median):     39.245 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   41.175 ms ±  5.465 ms  ┊ GC (mean ± σ):  4.15% ±  7.39%

#      ▂  ▅ █▁▁▂▁▁                                               
#   ▆▃███▃████████▅█▅▅▅▅▅▃▆█▁▁▃▃▁▅▅▅▃▁▃▃▃▆▆▅▁▁▁▃▁▆▃▁▃▁▃▁▃▁▁▁▃▁▃ ▃
#   35 ms           Histogram: frequency by time        54.5 ms <

#  Memory estimate: 14.01 MiB, allocs estimate: 204000.

@benchmark begin
    GLAbstraction.bind(layer_framebuffer)
    for id in range(1, N_TILES)
        activate_layer(layer_framebuffer, id)
        clear_buffers()
        draw(depth_prog, scene)
    end
end

# BenchmarkTools.Trial: 95 samples with 1 evaluation.
#  Range (min … max):  44.760 ms … 84.029 ms  ┊ GC (min … max): 0.00% … 13.94%
#  Time  (median):     50.644 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   52.745 ms ±  7.389 ms  ┊ GC (mean ± σ):  3.31% ±  6.01%

#    █  ▅ ▄      ▂                                               
#   ▃█▆█████▆██▅██▆▆▁▅▁▃▃▆▃▃▃▆▁▁▃▁▁▅▁█▁▃▁▁▁▁▁▃▁▁▁▃▁▁▁▁▁▁▁▁▁▁▁▁▃ ▁
#   44.8 ms         Histogram: frequency by time        79.6 ms <

#  Memory estimate: 14.02 MiB, allocs estimate: 204489.

# Benchmark copy & reindex
tile_data = CuArray(gpu_data(tile_framebuffer))
tile_indices = CuArray(LinearIndices(tiles))
layer_data = CuArray(gpu_data(layer_framebuffer))


@benchmark begin
    GLAbstraction.bind(tile_framebuffer)
    activate_all(tiles)
    clear_buffers()
    for id in range(1, N_TILES)
        activate_tile(tiles, id)
        draw(depth_prog, scene)
    end
    unsafe_copyto!(tile_data, tile_framebuffer)
    CUDA.@sync reindexed = tile_data[tile_indices]
end
# CUDA.@time  0.047745 seconds (204.13 k CPU allocations: 14.015 MiB) (1 GPU allocation: 38.147 MiB, 0.42% memmgmt time)

# BenchmarkTools.Trial: 91 samples with 1 evaluation.
#  Range (min … max):  45.374 ms … 86.173 ms  ┊ GC (min … max): 0.00% … 13.31%
#  Time  (median):     51.782 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   55.150 ms ±  9.397 ms  ┊ GC (mean ± σ):  3.13% ±  5.10%

#       ▄ ▁▅▁▂ █                                                 
#   ▆▁▆▃██████▅██▅▆▆▅▃▃▁▃▁▃▃▁▁▁▃▁▁▁▁▃▁▁▁▁▁▃▁▁▁▃▃▆▃▃▁▅▁▃▁▁▃▁▃▁▃▃ ▁
#   45.4 ms         Histogram: frequency by time        79.2 ms <

#  Memory estimate: 14.01 MiB, allocs estimate: 204127.

@benchmark begin
    GLAbstraction.bind(layer_framebuffer)
    for id in range(1, N_TILES)
        activate_layer(layer_framebuffer, id)
        clear_buffers()
        draw(depth_prog, scene)
    end
    CUDA.@sync unsafe_copyto!(layer_data, layer_framebuffer)
end
# CUDA.@time  0.045699 seconds (204.55 k CPU allocations: 14.018 MiB)

# BenchmarkTools.Trial: 93 samples with 1 evaluation.
#  Range (min … max):  46.796 ms … 74.089 ms  ┊ GC (min … max): 0.00% … 0.00%
#  Time  (median):     51.841 ms              ┊ GC (median):    0.00%
#  Time  (mean ± σ):   54.355 ms ±  5.563 ms  ┊ GC (mean ± σ):  3.08% ± 5.77%

#           ▆▃▆▂▃█                                               
#   ▄▁▄▁▇▄▇▄██████▅▅▅▇▄▅▁▁▁▁▄▅▁▁▁▄▄▄▄▅▅▁▄▇▇▄▄▁▄▅▁▄▄▁▄▁▁▁▁▁▁▁▁▁▅ ▁
#   46.8 ms         Histogram: frequency by time        69.1 ms <

#  Memory estimate: 14.02 MiB, allocs estimate: 204549.

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
