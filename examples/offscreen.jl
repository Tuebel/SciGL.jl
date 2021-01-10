# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using ModernGL, GLAbstraction, GLFW
using SciGL
using CoordinateTransformations, Rotations, StaticArrays
# TODO remove from package depencies
using ImageView

const WIDTH = 800
const HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)
framebuffer = color_framebuffer(WIDTH, HEIGHT)

# create ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init mesh
monkey = load_mesh("examples/meshes/monkey.obj", normal_prog) |> SceneObject

# Init Camera
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# Buffer settings
enable_depth_stencil()
set_clear_color()

# Draw to framebuffer
GLAbstraction.bind(framebuffer)

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    # events
    GLFW.PollEvents()
    # update camera pose
    camera.pose.t = Translation(1.5 * sin(2 * π * time() / 5), 0, 1.5 * cos(2 * π * time() / 5))
    camera.pose.R = lookat(camera, monkey, SVector{3}([0 1 0]))

    # draw
    clear_buffers()
    if floor(Int, time() / 5) % 3 == 0
        to_gpu(camera,  normal_prog)
        to_gpu(monkey,  normal_prog)
        draw(monkey,    normal_prog)
    elseif floor(Int, time() / 5) % 3 == 1
        to_gpu(camera,  silhouette_prog)
        to_gpu(monkey,  silhouette_prog)
        draw(monkey,    silhouette_prog)
    else
        to_gpu(camera,  depth_prog)
        to_gpu(monkey,  depth_prog)
        draw(monkey,    depth_prog)
    end
    img = gpu_data(framebuffer, 1)
    img = img[:,end:-1:1]
    imshow(canvas, transpose(img))
    sleep(2.5)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
