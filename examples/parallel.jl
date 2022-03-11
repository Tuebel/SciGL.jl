# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using BenchmarkTools
using ColorTypes
using CoordinateTransformations, Rotations
using GLAbstraction, GLFW
using SciGL
# TODO remove from package depencies

const WIDTH = 100
const HEIGHT = 100
const BENCHMARK = true
if BENCHMARK
    # Benchmark task not included
    const N_TASKS = 10
else
    using ImageView
    const N_TASKS = 3
end

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)
# Setup and check tiles
if BENCHMARK
    tiles = Tiles(N_TASKS + 1, WIDTH, HEIGHT)
else
    tiles = Tiles(N_TASKS, WIDTH, HEIGHT)
    SciGL.tile_indices(tiles, N_TASKS)
end
# Draw to framebuffer
# TODO
framebuffer = color_framebuffer(size(tiles)...)
GLAbstraction.bind(framebuffer)
cpu_data = gpu_data(framebuffer)
global_img = view_tile(cpu_data, tiles, 1)
img_lock = ReentrantLock()


# Buffer settings
enable_depth_stencil()
set_clear_color()

# Compile shader programs
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init scene
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj") |> SceneObject
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject
scene = Scene(camera, [monkey, monkey])

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# channel, cond = sync_render(tiles, render_cb)
channel = render_channel(tiles, framebuffer)
println(channel)

# Render the camera pose to the cpu
function render(program, scene, channel)
    tim = time()
    scene = @set scene.camera.pose.t = Translation(1.5 * sin(2 * π * tim / 5), 0, 1.5 * cos(2 * π * tim / 5))
    scene = @set scene.camera.pose.R = lookat(scene.camera, scene.meshes[1], [0 1 0])
    img = draw_to_cpu(program, scene, channel, (WIDTH, HEIGHT))
    # Some computation
    gray_img = img .|> green .|> Gray
    # TODO this causes memory allocation
    # gray_img = gray_img .|> Float64 .|> exp
    if !BENCHMARK
        lock(img_lock)
        try
            copy!(global_img, gray_img)
        finally
            unlock(img_lock)
        end
    end
end

function render_loop(program)
    println("Render loop, thread id ", Threads.threadid())
    while !GLFW.WindowShouldClose(window)
        render(program, scene, channel)
    end
end

if !BENCHMARK
    tasks = []
    push!(tasks, Threads.@spawn render_loop(normal_prog))
    push!(tasks, Threads.@spawn render_loop(depth_prog))
    push!(tasks, Threads.@spawn render_loop(silhouette_prog))

    # ImageView
    guidict = imshow(rand(HEIGHT, WIDTH))
    canvas = guidict["gui"]["canvas"]

    while !GLFW.WindowShouldClose(window)
        lock(img_lock)
        try
            img = global_img
            img = @view img[:, end:-1:1]
            img = transpose(img)
            imshow(canvas, img)
        finally
            unlock(img_lock)
        end
        sleep(0.1)
    end
else
    tasks = []
    for _ in 1:N_TASKS
        push!(tasks, Threads.@spawn render_loop(normal_prog))
    end
    # Benchmark needs to run in a separate thread, otherwise we would deadlock
    benchmark_task = Threads.@spawn begin
        @benchmark render(normal_prog, scene, channel)
    end
    # fetch(benchmark_task)
end
