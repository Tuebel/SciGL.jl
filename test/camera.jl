# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2023, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using SciGL
using Test

WIDTH = 800
HEIGHT = 600
DEPTH = 1
CROP_LEFT = Int(WIDTH / 2)
CROP_TOP = Int(HEIGHT / 2)
CROP_WIDTH = 200
CROP_HEIGHT = 200
cv_camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2)

# Draw cropped image
gl_context = depth_offscreen_context(CROP_WIDTH, CROP_HEIGHT, DEPTH, Array)
cube = load_mesh(gl_context, cube_path)
cube = @set cube.pose.translation = Translation(0, 0, 0)
cube = @set cube.scale = Scale(0.1)
crop_camera = crop(cv_camera, CROP_LEFT, CROP_TOP, CROP_WIDTH, CROP_HEIGHT)
crop_camera = @set crop_camera.pose.translation = Translation(1.3 * sin(0), 0, 1.3 * cos(0))
crop_camera = @set crop_camera.pose.rotation = lookat(crop_camera, cube, [0 1 0])
crop_scene = Scene(crop_camera, [cube])
# copy since the buffer is mapped and overwritten at next draw
crop_img = draw(gl_context, crop_scene) |> copy

@testset "Cropped Scene" begin
    @test !iszero(crop_img)
    @test maximum(crop_img) == 1.25
    @test minimum(crop_img) == 0
    # Cropped to lower left corner with cube in the middle
    @test crop_img[1, 1] == 1.25
    @test crop_img[end, end] == 0
end

# Create new context for uncropped reference, camera & mesh need to be reloaded into GPU memory
destroy_context(gl_context)
gl_context = depth_offscreen_context(WIDTH, HEIGHT, DEPTH, Array)

# Load scenes
cube_path = joinpath(dirname(pathof(SciGL)), "..", "examples", "meshes", "cube.obj")
cube = load_mesh(gl_context, cube_path)
cube = @set cube.pose.translation = Translation(0, 0, 0)
cube = @set cube.scale = Scale(0.1)
camera = Camera(cv_camera)
camera = @set camera.pose.translation = Translation(1.3 * sin(0), 0, 1.3 * cos(0))
camera = @set camera.pose.rotation = lookat(camera, cube, [0 1 0])
scene = Scene(camera, [cube])
# copy since the buffer is mapped and overwritten at next draw
full_img = draw(gl_context, scene) |> copy

@testset "OpenGL crop vs Array crop" begin
    # Sanity checks to hint errors
    @test !iszero(full_img)
    @test maximum(full_img) == 1.25
    @test minimum(full_img) == 0
    @test crop_img == full_img[CROP_LEFT+1:CROP_LEFT+CROP_WIDTH, CROP_TOP+1:CROP_TOP+CROP_HEIGHT]
end