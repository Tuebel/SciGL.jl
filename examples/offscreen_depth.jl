# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using SciGL
using ImageView

const WIDTH = 801
const HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
gl_context = depth_offscreen_context(WIDTH, HEIGHT, 3)
# create ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Init scene with normal_prog as it uses most attributes
cube = load_mesh(gl_context, "examples/meshes/cube.obj")
cube = @set cube.pose.translation = Translation(1, 0, 0)
monkey = load_mesh(gl_context, "examples/meshes/monkey.obj")
monkey = @set monkey.pose.translation = Translation(0, 0, 0)
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> Camera
camera = @set camera.pose.translation = Translation(1.3 * sin(π / 4), 0, 1.3 * cos(π / 4))
camera = @set camera.pose.rotation = lookat(camera, monkey, [0 1 0])
# WARN if not using Scene, to_gpu has to be called for the camera
scene1 = Scene(camera, [cube, monkey])
scene2 = @set scene1.camera.pose.translation = Translation(1.3 * sin(5 * π / 4), 0, 1.3 * cos(5 * π / 4))
scene2 = @set scene2.camera.pose.rotation = lookat(scene2.camera, monkey, [0 1 0])
scene3 = @set scene1.camera.pose.translation = Translation(1.3 * sin(3 * π / 4), 0, 1.3 * cos(3 * π / 4))
scene3 = @set scene3.camera.pose.rotation = lookat(scene3.camera, monkey, [0 1 0])
scenes = [scene1, scene2, scene3]

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(gl_context.window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# Draw until we receive a close event
while !GLFW.WindowShouldClose(gl_context.window)
    # events
    GLFW.PollEvents()
    # draw
    imgs = draw(gl_context, scenes)
    if floor(Int, time() / 2) % 3 == 0
        img = imgs[:, :, 1]
    elseif floor(Int, time() / 5) % 3 == 1
        img = imgs[:, :, 2]
    else
        img = imgs[:, :, 3]
    end
    # Simplified interface, performance only slightly worse
    imshow(canvas, transpose(img))
    sleep(0.1)
end

# needed if you're running this from the REPL
destroy_context(gl_context)
