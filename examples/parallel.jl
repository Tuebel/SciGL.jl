# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using GLAbstraction, GLFW
using SciGL
using CoordinateTransformations, Rotations
# TODO remove from package depencies
using ImageView

const WIDTH = 800
const HEIGHT = 600

const WIDTH = 800
const HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)

# Setup and check tiles
tiles = Tiles(3, WIDTH, HEIGHT)
SciGL.tile_indices(tiles, 3)

# Draw to framebuffer
fb_size = full_size(tiles)
framebuffer = color_framebuffer(fb_size...)
GLAbstraction.bind(framebuffer)
cpu_data = gpu_data(framebuffer, 1)
img = view_tile(cpu_data, tiles, 1)

# Buffer settings
enable_depth_stencil()
set_clear_color()

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init scene
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj") |> SceneObject
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject
scene = SciGL.Scene(camera, [monkey, monkey])

# ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# TODO using globals
function render_cb()
    unsafe_copyto!(cpu_data, framebuffer.attachments[1])
    img = cpu_data[:, end:-1:1]
    imshow(canvas, transpose(img))
    sleep(0.1)
end
channel, cond = sync_render!(tiles, render_cb)

# Render the camera pose to the cpu
function render_task(id)
    while true
        tim = time()
        # TODO probably race condition -> deepcopy scene when spawning thread
        scene.camera.pose.t = Translation(1.5 * sin(2 * π * tim / 5), 0, 1.5 * cos(2 * π * tim / 5))
        scene.camera.pose.R = lookat(scene.camera, scene.meshes[1], [0 1 0])
        # TODO Do not use println() or sleep between draw and view_tile -> notify fails
        if id == 1
            draw(silhouette_prog, scene, channel, id)
        elseif id == 2
            draw(depth_prog, scene, channel, id)
        else
            draw(normal_prog, scene, channel, id)
        end
        # Synchronized read for all tasks
        img = view_tile(cpu_data, tiles, id)
    end
end

tasks = Vector{Task}(undef, 3)
for id in 1:3
    tasks[id] = Threads.@spawn render_task(id)
end

# needed if you're running this from the REPL
# GLFW.DestroyWindow(window)