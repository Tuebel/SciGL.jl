# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2023, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using SciGL
using Test

WIDTH = 800
HEIGHT = 600
DEPTH = 1
# Mind Julia arrays starting at 1
CROP_LEFT = Int(WIDTH / 2) + 1
CROP_RIGHT = WIDTH - 10
# Mind Julia arrays starting at 1
CROP_TOP = Int(HEIGHT / 2) + 1
CROP_BOTTOM = HEIGHT - 10
# WARN: Tests have been designed for these parameters. Do not change.
cv_camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2)

# Load mesh, transfer later
cube_path = joinpath(dirname(pathof(SciGL)), "..", "examples", "meshes", "cube.obj")
scale = Scale(0.2)
cube_mesh = scale(load(cube_path))

# Helper tro transfer the mesh and set the position
function load_cube(gl_context)
    cube = upload_mesh(gl_context, cube_mesh)
    cube = @set cube.pose.translation = Translation(0.2, 0.2, 0.7)
end

# Use regular (uncropped) camera
gl_context = depth_offscreen_context(WIDTH, HEIGHT, DEPTH, Array)

# Load scenes
camera = Camera(cv_camera)
cube = load_cube(gl_context)
scene = Scene(camera, [cube])
# copy since the buffer is mapped and overwritten at next draw
full_img = draw(gl_context, scene) |> copy
# Gray.(full_img .+ 1e-2)' # + 1e-2 avoids glitching in vscode plot

# Sanity checks to hint errors
@testset "Full camera " begin
    # Julia image convention differs from OpenGL: (y, x) vs. (x, y)
    @test size(full_img) == (HEIGHT, WIDTH)
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
CROP_WIDTH, CROP_HEIGHT = crop_size(CROP_LEFT, CROP_RIGHT, CROP_TOP, CROP_BOTTOM)
gl_context = depth_offscreen_context(CROP_WIDTH, CROP_HEIGHT, DEPTH, Array)

cube = load_cube(gl_context)
crop_camera = crop(cv_camera, CROP_LEFT, CROP_RIGHT, CROP_TOP, CROP_BOTTOM)
crop_scene = Scene(crop_camera, [cube])
# copy since the buffer is mapped and overwritten at next draw
crop_img = draw(gl_context, crop_scene) |> copy

# Sanity checks to hint errors
@testset "Cropped camera" begin
    # Julia image convention differs from OpenGL: (y, x) vs. (x, y)
    @test size(crop_img) == (CROP_BOTTOM - CROP_TOP + 1, CROP_RIGHT - CROP_LEFT + 1)
    @test !iszero(crop_img)
    # Cube of size 0.2 at distance 0.7 → closest point at 0.6, furthest at 0.8
    @test minimum(crop_img[crop_img.>0]) ≈ 0.6
    @test 0.79 < maximum(crop_img) < 0.8
    @test minimum(crop_img) == 0
    # Cube should be in lower right (-Y=up, X=right)
    @test crop_img[begin, begin] == 0
    @test crop_img[end, end] ≈ 0.6
    # Array view should be the same as OpenGL crop. Equality fails for some CPU/GPU combinations, thus approx.
    @test crop_img ≈ full_img[CROP_TOP:CROP_BOTTOM, CROP_LEFT:CROP_RIGHT]
end

destroy_context(gl_context)
