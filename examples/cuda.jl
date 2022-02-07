# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using CoordinateTransformations, Rotations
using CUDA
using GLAbstraction, GLFW
using SciGL

const WIDTH = 800
const HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_window(WIDTH, HEIGHT)
# On Intel copying data from a texture or an RBO does not really make a difference
framebuffer = depth_framebuffer(WIDTH, HEIGHT)
texture = framebuffer.attachments[1]

# Fill undefined and then copy empty framebuffer -> should change
cuarray = CuArray{Float32}(undef, (WIDTH, HEIGHT))
display(maximum(cuarray))
cpu_data = Matrix{Float32}(undef, WIDTH, HEIGHT)
display(maximum(cpu_data))

# Compile shader program
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init mesh
monkey = load_mesh(depth_prog, "examples/meshes/monkey.obj") |> SceneObject

# Init Camera
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject

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
    to_gpu(depth_prog, camera)
    to_gpu(depth_prog, monkey)
    draw(depth_prog, monkey)

    # Maximum depth value should change for rotating monkey
    unsafe_copyto!(cuarray, texture)
    display(maximum(cuarray))
    unsafe_copyto!(cpu_data, texture)
    display(maximum(cpu_data))
    sleep(0.1)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
