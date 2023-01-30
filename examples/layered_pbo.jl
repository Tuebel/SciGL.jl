# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using CUDA
using SciGL
using ImageView

const WIDTH = 800
const HEIGHT = 600
const USE_CUDA = true

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)

# On Intel copying data from a texture or an RBO does not really make a difference
framebuffer = color_framebuffer(WIDTH, HEIGHT, 3)
texture = first(color_attachments(framebuffer))

# Map once
pbo = PersistentBuffer(texture)
# WARN mapping to CPU & CUDA leads to NULL in CPU data (probably for a reason)
data = if USE_CUDA
    CuArray(pbo)
else
    Array(pbo)
end

# Compile shader program
normal_prog = compile_shader(SimpleVert, NormalFrag)
silhouette_prog = compile_shader(SimpleVert, SilhouetteFrag)
depth_prog = compile_shader(SimpleVert, DepthFrag)

# Init scene
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj")
monkey = @set monkey.scale = Scale(1, 0.7, 0.8)
cube = load_mesh(normal_prog, "examples/meshes/cube.obj")
cube = @set cube.pose.translation = Translation(1, 0, 0)
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> Camera
scene = SciGL.Scene(camera, [monkey])
cube_scene = SciGL.Scene(camera, [monkey, cube])

# create ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# Buffer settings
enable_depth_stencil()
set_clear_color()

# Draw to framebuffer
glbind(framebuffer)

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    # events
    GLFW.PollEvents()

    scene = @set scene.camera.pose.translation = Translation(1.3 * sin(2 * π * time() / 5), 0, 1.3 * cos(2 * π * time() / 5))
    scene = @set scene.camera.pose.rotation = lookat(scene.camera, monkey, [0 1 0])
    cube_scene = @set cube_scene.camera = scene.camera

    activate_layer(framebuffer, 1)
    clear_buffers()
    draw(silhouette_prog, scene)

    activate_layer(framebuffer, 2)
    clear_buffers()
    draw(depth_prog, scene)

    # Test whether 2D DepthStencil RenderBuffer works with 3D Texture 
    activate_layer(framebuffer, 3)
    clear_buffers()
    draw(normal_prog, cube_scene)

    # Display one image
    id = time() ÷ 5 % 3 + 1 |> Int
    # Test if both work and show the same image
    unsafe_copyto!(pbo, framebuffer)
    # To test whether partial copy works, only silhouette_prog should move
    # unsafe_copyto!(pbo, framebuffer, WIDTH, HEIGHT)
    img = if USE_CUDA
        Array(data)
    else
        data
    end
    img = @view img[:, :, id]
    img = @view img[:, end:-1:1]
    imshow(canvas, transpose(img))
    sleep(0.05)
end

# needed if you're running this from the REPL
destroy_context(window)
