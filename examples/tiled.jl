# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using CoordinateTransformations, Rotations
using GLAbstraction, GLFW
using SciGL
using StaticArrays
# TODO remove from package depencies
using ImageView

const WIDTH = 800
const HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)

# Setup and check tiles
tiles = Tiles(3, WIDTH, HEIGHT)
SciGL.tile_indices(tiles, 3)

# Draw to framebuffer
framebuffer = color_framebuffer(size(tiles)...)
texture = framebuffer.attachments[1]
GLAbstraction.bind(framebuffer)
cpu_data = typeof(gpu_data(framebuffer))(undef, WIDTH, HEIGHT)

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

# create ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    # events
    GLFW.PollEvents()

    scene = @set scene.camera.pose.t = Translation(1.5 * sin(2 * π * time() / 5), 0, 1.5 * cos(2 * π * time() / 5))
    scene = @set scene.camera.pose.R = lookat(scene.camera, monkey, [0 1 0])

    # draw
    activate_all(tiles)
    clear_buffers()

    activate_tile(tiles, 1)
    draw(silhouette_prog, scene)

    activate_tile(tiles, 2)
    draw(depth_prog, scene)

    activate_tile(tiles, 3)
    draw(normal_prog, scene)

    # copy only the required part of the tiles to the CPU
    id = time() ÷ 5 % 3 + 1 |> Int
    GLAbstraction.unsafe_copyto!(cpu_data, framebuffer, tiles, id)
    # Alternative: Copy all and the select the view#
    # cpu_data = gpu_data(framebuffer)
    # img = view_tile(cpu_data, tiles, 1)
    img = cpu_data[:, end:-1:1] |> transpose
    imshow(canvas, img)
    sleep(0.1)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
