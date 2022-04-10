# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using CoordinateTransformations, Rotations
using GLAbstraction, GLFW
using SciGL
using ImageView

const WIDTH = 801
const HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)
# On Intel copying data from a texture or an RBO does not really make a difference
framebuffer = color_framebuffer_rbo(WIDTH, HEIGHT)
# create ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init mesh
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj") |> SceneObject

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
    camera = @set camera.pose.t = Translation(1.5 * sin(2 * π * time() / 5), 0, 1.5 * cos(2 * π * time() / 5))
    camera = @set camera.pose.R = lookat(camera, monkey, [0 1 0])

    # draw
    clear_buffers()
    if floor(Int, time() / 5) % 3 == 0
        to_gpu(normal_prog, camera)
        to_gpu(normal_prog, monkey)
        draw(normal_prog, monkey)
    elseif floor(Int, time() / 5) % 3 == 1
        to_gpu(silhouette_prog, camera)
        to_gpu(silhouette_prog, monkey)
        draw(silhouette_prog, monkey)
    else
        to_gpu(depth_prog, camera)
        to_gpu(depth_prog, monkey)
        draw(depth_prog, monkey)
    end
    # Simplified interface, performance only slightly worse
    img = gpu_data(framebuffer)
    img = img[:, end:-1:1]
    imshow(canvas, transpose(img))
    sleep(0.1)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
