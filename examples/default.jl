# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

# WARN Do not run this if you want Revise to work
# include("../src/SciGL.jl")
# using .SciGL

using Accessors
using SciGL

const WIDTH = 800
const HEIGHT = 600

# Create the window. This sets all the hints and makes the context current.
window = context_window(WIDTH, HEIGHT)

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init scene with normal_prog as it uses most attributes
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject
cube = load_mesh(normal_prog, "examples/meshes/cube.obj") |> SceneObject
cube = @set cube.pose.translation = Translation(1, 0, 0)
cube = @set cube.scale = Scale(0.1, 0.3, 0.5)
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj") |> SceneObject
monkey = @set monkey.pose.translation = Translation(0, 0, 0)
scene = Scene(camera, [cube, monkey])

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# Buffer settings
enable_depth_stencil()
set_clear_color()

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    # events
    GLFW.PollEvents()
    # update camera pose
    scene = @set scene.camera.pose.translation = Translation(1.3 * sin(2 * π * time() / 5), 0, 1.3 * cos(2 * π * time() / 5))
    scene = @set scene.camera.pose.rotation = lookat(scene.camera, monkey, [0 1 0])

    # draw
    clear_buffers()
    if floor(Int, time() / 5) % 3 == 0
        draw(normal_prog, scene)
    elseif floor(Int, time() / 5) % 3 == 1
        draw(silhouette_prog, scene)
    else
        draw(depth_prog, scene)
    end
    GLFW.SwapBuffers(window)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
