# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

# WARN Do not run this if you want Revise to work
# include("../src/SciGL.jl")
# using .SciGL

using Accessors
using SciGL

WIDTH = 800
HEIGHT = 600

# Create the window. This sets all the hints and makes the context current.
window = context_window(WIDTH, HEIGHT)

# Compile shader program
normal_prog = compile_shader(SimpleVert, NormalFrag)
silhouette_prog = compile_shader(SimpleVert, SilhouetteFrag)
depth_prog = compile_shader(SimpleVert, DepthFrag)
dist_prog = compile_shader(SimpleVert, DistanceFrag)

# Init scene with normal_prog as it uses most attributes
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * WIDTH, WIDTH / 2, HEIGHT / 2)
scale = Scale(0.1, 0.3, 0.5)
cube_mesh = load("examples/meshes/cube.obj")
cube = upload_mesh(normal_prog, scale(cube_mesh))
@reset cube.pose.translation = Translation(1, 0, 0)
monkey = upload_mesh(normal_prog, "examples/meshes/monkey.obj")
@reset monkey.pose.translation = Translation(0, 0, 0)
scene1 = Scene(camera, [cube, monkey])

scale = Scale(0.5)
cube2 = upload_mesh(normal_prog, scale(cube_mesh))
@reset cube2.pose.translation = Translation(0, 0, 0)
scene2 = Scene(camera, [cube, cube2])

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    # events
    GLFW.PollEvents()
    # Camera rotates around mathematically positive Z
    @reset scene1.camera.pose.translation = Translation(1.3 * cos(2 * π * time() / 5), 1.3 * sin(2 * π * time() / 5), 0)
    # OpenCV vs. OpenGL: Y down vs. Y up → monkey upside down, see offscreen.jl where the memory layout is correct.
    @reset scene1.camera.pose.rotation = lookat(scene1.camera, monkey, [0, 0, 1])
    @reset scene2.camera.pose = scene1.camera.pose

    # draw
    clear_buffers()
    if floor(Int, time() / 5) % 4 == 0
        draw(normal_prog, scene1)
    elseif floor(Int, time() / 5) % 4 == 1
        draw(silhouette_prog, scene2)
    elseif floor(Int, time() / 5) % 4 == 2
        draw(depth_prog, scene1)
    else
        draw(dist_prog, scene2)
    end
    GLFW.SwapBuffers(window)
end

# needed if you're running this from the REPL
destroy_context(window)
