# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using CUDA
using SciGL
using ImageView

WIDTH = 801
HEIGHT = 600

# TODO
# Compile shader program
# normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
# silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
# depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Create the GLFW window. This sets all the hints and makes the context current.
gl_context = if cuda_interop_available()
    color_offscreen_context(WIDTH, HEIGHT, 1, CuArray)
else
    color_offscreen_context(WIDTH, HEIGHT, 1, Array)
end
# create ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Init scene with normal_prog as it uses most attributes
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * WIDTH, WIDTH / 2, HEIGHT / 2) |> Camera
cube = upload_mesh(gl_context, "examples/meshes/cube.obj")
@reset cube.pose.translation = Translation(1, 0, 0)
monkey = upload_mesh(gl_context, "examples/meshes/monkey.obj")
@reset monkey.pose.translation = Translation(0, 0, 0)
scene = Scene(camera, [cube, monkey])

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(gl_context.window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

loops = UInt128(0)
seconds = @elapsed for _ in 1:200
    # events
    GLFW.PollEvents()
    # Camera rotates around mathematically positive Z
    @reset scene.camera.pose.translation = Translation(1.3 * cos(2 * π * time() / 5), 1.3 * sin(2 * π * time() / 5), 0)
    @reset scene.camera.pose.rotation = lookat(scene.camera, monkey, [0, 0, 1])
    img = draw(gl_context, scene)
    imshow(canvas, img |> Array |> transpose)
    sleep(1e-6)
    loops += 1
end
println("Average fps: $(loops / seconds)")

# needed if you're running this from the REPL
destroy_context(gl_context)