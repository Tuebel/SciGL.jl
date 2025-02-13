# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using SciGL
using Images

WIDTH = 801
HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
gl_context = depth_offscreen_context(WIDTH, HEIGHT, 3)

# Init scene with normal_prog as it uses most attributes
cube = upload_mesh(gl_context, "examples/meshes/cube.obj")
cube = @set cube.pose.translation = Translation(1, 0, 0)
monkey = upload_mesh(gl_context, "examples/meshes/monkey.obj")
monkey = @set monkey.pose.translation = Translation(0, 0, 0)
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * WIDTH, WIDTH / 2, HEIGHT / 2) |> Camera
camera = @set camera.pose.translation = Translation(1.3 * sin(π / 4), 1.3 * cos(π / 4), 0)
camera = @set camera.pose.rotation = lookat(camera, monkey, [0, 0, 1])
# WARN if not using Scene, to_gpu has to be called for the camera
scene1 = Scene(camera, [cube, monkey])
scene2 = @set scene1.camera.pose.translation = Translation(1.3 * sin(5 * π / 4), 1.3 * cos(5 * π / 4), 0)
scene2 = @set scene2.camera.pose.rotation = lookat(scene2.camera, monkey, [0, 0, 1])
scene3 = @set scene1.camera.pose.translation = Translation(1.3 * sin(3 * π / 4), 1.3 * cos(3 * π / 4), 0)
scene3 = @set scene3.camera.pose.rotation = lookat(scene3.camera, monkey, [0, 0, 1])
scenes = [scene1, scene2, scene3]

imgs = draw(gl_context, scenes) .|> Gray
view(imgs, :, :, 1) |> transpose |> simshow
view(imgs, :, :, 2) |> transpose |> simshow
view(imgs, :, :, 3) |> transpose |> simshow
# Simplified interface, performance only slightly worse
# needed if you're running this from the REPL
destroy_context(gl_context)
