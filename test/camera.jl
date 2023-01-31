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
CROP_WIDTH = Int(WIDTH / 4)
CROP_HEIGHT = Int(HEIGHT / 3)
cv_camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2)

# Use regular (uncropped) camera
gl_context = depth_offscreen_context(WIDTH, HEIGHT, DEPTH, Array)

# Load scenes
cube_path = joinpath(dirname(pathof(SciGL)), "..", "examples", "meshes", "cube.obj")
cube = load_mesh(gl_context, cube_path)
cube = @set cube.pose.translation = Translation(0.2, 0.2, 0.7)
cube = @set cube.scale = Scale(0.2)
camera = Camera(cv_camera)
scene = Scene(camera, [cube])
# copy since the buffer is mapped and overwritten at next draw
full_img = draw(gl_context, scene) |> copy

@testset "Full camera " begin
    # Sanity checks to hint errors
    @test !iszero(full_img)
    # Cube of size 0.2 at distance 0.7 → closest point at 0.6, furthest at 0.8
    @test minimum(full_img[full_img.>0]) ≈ 0.6
    @test 0.79 < maximum(full_img) < 0.8
    @test minimum(full_img) == 0
    # Cube should be in lower right (-Y=up, X=right)
    @test full_img[begin, begin] == 0
    @test full_img[end, end] ≈ 0.6
end

# Create new context for cropped view, camera & mesh need to be reloaded into GPU memory
destroy_context(gl_context)
gl_context = depth_offscreen_context(CROP_WIDTH, CROP_HEIGHT, DEPTH, Array)

cube = load_mesh(gl_context, cube_path)
cube = @set cube.pose.translation = Translation(0.2, 0.2, 0.7)
cube = @set cube.scale = Scale(0.2)
# TODO why 0 for top?
crop_camera = crop(cv_camera, CROP_LEFT, CROP_TOP, CROP_WIDTH, CROP_HEIGHT)
crop_scene = Scene(crop_camera, [cube])
# copy since the buffer is mapped and overwritten at next draw
crop_img = draw(gl_context, crop_scene) |> copy

@testset "Cropped camera" begin
    # Sanity checks to hint errors
    @test !iszero(crop_img)
    # Cube of size 0.2 at distance 0.7 → closest point at 0.6, furthest at 0.8
    @test minimum(crop_img[crop_img.>0]) ≈ 0.6
    @test 0.79 < maximum(crop_img) < 0.8
    @test minimum(crop_img) == 0
    # Cube should be in lower right (-Y=up, X=right)
    @test crop_img[begin, begin] == 0
    @test crop_img[end, end] ≈ 0.6
end

@testset "OpenGL crop vs Array crop" begin
    @test crop_img == full_img[CROP_LEFT+1:CROP_LEFT+CROP_WIDTH, CROP_TOP+1:CROP_TOP+CROP_HEIGHT]
end
