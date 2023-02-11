# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using CUDA
using SciGL
using ImageView

WIDTH = 801
HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)
# On Intel copying data from a texture or an RBO does not really make a difference
framebuffer = depth_framebuffer(WIDTH, HEIGHT)
# WARN we cannot map the OpenGL texture to CUDA once and then reuse it, since the pointer changes.
texture = framebuffer.attachments[1]
cu_array = CuArray{Float32}(undef, size(texture))
# create ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init mesh
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj")

# Init Camera
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * WIDTH, WIDTH / 2, HEIGHT / 2) |> Camera

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
    # Camera rotates around mathematically positive Z
    camera = @set camera.pose.translation = Translation(1.3 * cos(2 * π * time() / 5), 1.3 * sin(2 * π * time() / 5), 0)
    # WARN if not using Scene, to_gpu has to be called for the camera
    camera = @set camera.pose.rotation = lookat(camera, monkey, [0, 0, 1])

    # draw
    clear_buffers()
    if floor(Int, time() / 5) % 3 == 0
        to_gpu(normal_prog, camera)
        draw(normal_prog, monkey)
    elseif floor(Int, time() / 5) % 3 == 1
        to_gpu(silhouette_prog, camera)
        draw(silhouette_prog, monkey)
    else
        to_gpu(depth_prog, camera)
        draw(depth_prog, monkey)
    end
    # Simplified interface, performance only slightly worse
    unsafe_copyto!(cu_array, texture)
    img = Array(cu_array)[:, end:-1:1]
    imshow(canvas, cu_array |> Array |> transpose)
    sleep(0.05)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)