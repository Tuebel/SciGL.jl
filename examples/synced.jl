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

# Draw to framebuffer
framebuffer = color_framebuffer(WIDTH, HEIGHT)
GLAbstraction.bind(framebuffer)
global_img = gpu_data(framebuffer, 1)
img_lock = ReentrantLock()

# Buffer settings
enable_depth_stencil()
set_clear_color()

# Compile shader programs
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init scene
monkey = load_mesh(normal_prog, "examples/meshes/monkey.obj") |> SceneObject
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject
scene = Scene(camera, [monkey, monkey])

# ImageView
guidict = imshow(rand(HEIGHT, WIDTH))
canvas = guidict["gui"]["canvas"]

# Key callbacks GLFW.GetKey does not seem to work
GLFW.SetKeyCallback(window, (win, key, scancode, action, mods) -> begin
    key == GLFW.KEY_ESCAPE && GLFW.SetWindowShouldClose(window, true)
    println("Registered $key")
end)

# This is where the magic happens 
channel = render_channel()

# Render the camera pose to the cpu
function render_loop(program, scene, framebuffer, channel)
    println("Render loop thread id ", Threads.threadid())
    while true
        tim = time()
        scene.camera.pose.t = Translation(1.5 * sin(2 * π * tim / 5), 0, 1.5 * cos(2 * π * tim / 5))
        scene.camera.pose.R = lookat(scene.camera, scene.meshes[1], [0 1 0])
        img = draw_to_cpu_sync(program, scene, framebuffer, channel)
        lock(img_lock)
        try
            copy!(global_img, img)
        finally
            unlock(img_lock)
        end
    end
end

# Deepcopy the scene to avoid race conditions
normal_task = Threads.@spawn render_loop(normal_prog, deepcopy(scene), framebuffer, channel)
silhouette_task = Threads.@spawn render_loop(silhouette_prog, deepcopy(scene), framebuffer, channel)
depth_task = Threads.@spawn render_loop(depth_prog, deepcopy(scene), framebuffer, channel)

while !GLFW.WindowShouldClose(window)
    lock(img_lock)
    try
        # img = gpu_data(framebuffer, 1)
        img = global_img
        img = @view img[:, end:-1:1]
        img = transpose(img)
        imshow(canvas, img)
    finally
        unlock(img_lock)
    end
    # Render task on same thread -> give it some time
    sleep(0.1)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)