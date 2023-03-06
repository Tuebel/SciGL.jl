# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using SciGL
using ImageView

WIDTH = 801
HEIGHT = 600

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

# Init scene with normal_prog as it uses most attributes
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * WIDTH, WIDTH / 2, HEIGHT / 2) |> Camera
cube = upload_mesh(normal_prog, "examples/meshes/cube.obj")
cube = @set cube.pose.translation = Translation(1, 0, 0)
monkey = upload_mesh(normal_prog, "examples/meshes/monkey.obj")
monkey = @set monkey.pose.translation = Translation(0, 0, 0)

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
        draw(normal_prog, cube)
    elseif floor(Int, time() / 5) % 3 == 1
        to_gpu(silhouette_prog, camera)
        draw(silhouette_prog, monkey)
    else
        to_gpu(depth_prog, camera)
        draw(depth_prog, cube)
        draw(depth_prog, monkey)
    end
    # Simplified interface, performance only slightly worse
    img = gpu_data(framebuffer)
    # NOTE monkey upside down is correct since OpenCV uses X=right, Y=down, Z=forward convention
    imshow(canvas, transpose(img))
    sleep(0.05)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)