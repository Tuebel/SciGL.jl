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
    # Main / Benchmark task not included
    const N_TASKS = 10
else
    N_TASKS = 3
    using ImageView
end


# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)

# Draw to framebuffer
framebuffer = color_framebuffer(WIDTH, HEIGHT)
GLAbstraction.bind(framebuffer)
cpu_data = gpu_data(framebuffer)
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

# This is where the magic happens 
channel = render_channel()

# Render the camera pose to the cpu
function render(program, scene, framebuffer, channel, cpu_data)
    tim = time()
    scene = @set scene.camera.pose.t = Translation(1.3 * sin(2 * π * tim / 5), 0, 1.5 * cos(2 * π * tim / 5))
    scene = @set scene.camera.pose.R = lookat(scene.camera, scene.meshes[1], [0 1 0])
    img = draw_to_cpu(program, scene, framebuffer, channel, cpu_data)
    # Some computation
    gray_img = img .|> green .|> Gray
    # TODO this causes memory allocation
    # gray_img .|> Float64 .|> exp
end

function render_loop(cpu_data)
    println("Render loop, thread id ", Threads.threadid())
    # Preallocate once
    while !GLFW.WindowShouldClose(window)
        render(normal_prog, scene, framebuffer, channel, cpu_data)
    end
end

tasks = []
for _ in 1:N_TASKS
    push!(tasks, Threads.@spawn render_loop(deepcopy(cpu_data)))
end

if !BENCHMARK
    function render_screen(cpu_data)
        # ImageView
        guidict = imshow(rand(HEIGHT, WIDTH))
        canvas = guidict["gui"]["canvas"]

        println("Render loop, thread id ", Threads.threadid())
        while !GLFW.WindowShouldClose(window)
            img = render(normal_prog, scene, framebuffer, channel, cpu_data)
            img = @view img[:, end:-1:1]
            img = transpose(img)
            # imshow needs some sleep
            imshow(canvas, img,)
            sleep(0.1)
        end
    end
    render_screen(deepcopy(cpu_data))
end

if BENCHMARK
    # Preallocate once
    benchmark_data = gpu_data(framebuffer)
    @benchmark render(normal_prog, scene, framebuffer, channel, benchmark_data)
end
