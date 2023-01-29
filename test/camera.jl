# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2023, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using SciGL
using Test

# Create the GLFW window. This sets all the hints and makes the context current.
WIDTH = 800
HEIGHT = 600
DEPTH = 1

gl_context = depth_offscreen_context(WIDTH, HEIGHT, DEPTH, Array)

# Load scenes
cube_path = joinpath(dirname(pathof(SciGL)), "..", "examples", "meshes", "cube.obj")
cube = load_mesh(gl_context, cube_path)
cube = @set cube.pose.translation = Translation(0, 0, 0)
cube = @set cube.scale = Scale(0.1)
cv_camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2)

camera = Camera(cv_camera)
@test camera isa SceneObject{Camera}

camera = @set camera.pose.translation = Translation(1.3 * sin(0), 0, 1.3 * cos(0))
camera = @set camera.pose.rotation = lookat(camera, cube, [0 1 0])
scene = Scene(camera, [cube])

activate_layer(gl_context.framebuffer, 1)
clear_buffers()
full_img = draw(gl_context, scene) |> copy
@test !iszero(full_img)
@test maximum(full_img) == 1.25
@test minimum(full_img) == 0

# TODO OpenGL texture has origin in left-bottom and requires flipping to correctly crop it. SciGL is targeted at offscreen rendering and calculations so the default should probably be an image in OpenCV convention which will bed displayed upside down in the context window.
flipped_img = @view full_img[:, end:-1:1]
array_crop = @view flipped_img[Int(WIDTH / 2)+1:WIDTH, Int(HEIGHT / 2)+1:HEIGHT]
@test maximum(array_crop) == 1.25
@test minimum(array_crop) == 0

crop_camera = crop(cv_camera, WIDTH / 2, HEIGHT / 2, WIDTH / 2, HEIGHT / 2)
crop_camera = @set crop_camera.pose.translation = Translation(1.3 * sin(0), 0, 1.3 * cos(0))
crop_camera = @set crop_camera.pose.rotation = lookat(crop_camera, cube, [0 1 0])
crop_scene = Scene(crop_camera, [cube])
crop_img = draw(gl_context, crop_scene)
# TODO why do I have to start at second index
flipped_crop = @view crop_img[2:2:end, end:-2:2]
@test array_crop == flipped_crop