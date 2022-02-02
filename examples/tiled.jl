# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using GLAbstraction, GLFW
using SciGL
using CoordinateTransformations, Rotations
# TODO remove from package depencies
using ImageView

const WIDTH = 800
const HEIGHT = 600

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)

tiles = Tiles(3, WIDTH, HEIGHT)
SciGL.tile_indices(tiles, 3)
fb_size = full_size(tiles)
SciGL.gl_tile_indices(tiles, 3)

framebuffer = color_framebuffer(fb_size...)

# create ImageView
guidict = imshow(rand(fb_size...))
canvas = guidict["gui"]["canvas"]

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init mesh
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj") |> SceneObject

# Init Camera
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

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
    camera.pose.t = Translation(1.5 * sin(2 * π * time() / 5), 0, 1.5 * cos(2 * π * time() / 5))
    camera.pose.R = lookat(camera, monkey, [0 1 0])
    # draw
    activate_full(tiles)
    clear_buffers()

    activate_tile(tiles, 1)
    to_gpu(silhouette_prog, camera)
    to_gpu(silhouette_prog, monkey)
    draw(silhouette_prog, monkey)

    activate_tile(tiles, 2)
    to_gpu(depth_prog, camera)
    to_gpu(depth_prog, monkey)
    draw(depth_prog, monkey)

    activate_tile(tiles, 3)
    to_gpu(normal_prog, camera)
    to_gpu(normal_prog, monkey)
    draw(normal_prog, monkey)

    # copy to cpu
    img = gpu_data(framebuffer, 1)

    # view only a single image from the texture
    img = img[:, end:-1:1]
    if floor(Int, time() / 5) % 3 == 0
        img = view_tile(img, tiles, 1)
    elseif floor(Int, time() / 5) % 3 == 1
        img = view_tile(img, tiles, 2)
    else
        img = view_tile(img, tiles, 3)
    end
    # img = transpose(img)
    imshow(canvas, transpose(img))
    sleep(0.1)
end
# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
