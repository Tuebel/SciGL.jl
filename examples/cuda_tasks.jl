# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using BenchmarkTools
using CUDA
using SciGL

const N_TASKS = 1000
const WIDTH = 100
const HEIGHT = 100

# Create the GLFW window. This sets all the hints and makes the context current.
window = context_offscreen(WIDTH, HEIGHT)
# On Intel copying data from a texture or an RBO does not really make a difference
framebuffer = depth_framebuffer(WIDTH, HEIGHT)
GLAbstraction.bind(framebuffer)
texture = framebuffer.attachments[1]
enable_depth_stencil()
set_clear_color()

# Compile shader program
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)
# Init scene
monkey = load_mesh(depth_prog, "examples/meshes/monkey.obj") |> SceneObject
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject
scene = Scene(camera, [monkey, monkey])
scene = @set scene.camera.pose.t = Translation(1.5, 0, 1.5)
scene = @set scene.camera.pose.R = lookat(scene.camera, scene.meshes[1], [0 1 0])

# This is where the magic happens 
channel = render_channel()

# Render the camera pose to the cpu
function render_to_cpu_sum(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel)
    img = Matrix{Float32}(undef, size(texture))
    # Only this time is synchronized with other tasks
    draw_to_cpu(program, scene, framebuffer, channel, img)
    sum(img)
end

# Copy to CUDA must block the OpenGL render calls
function draw_to_cuda(program, scene, texture, cu_mat)
    clear_buffers()
    draw(program, scene)
    unsafe_copyto!(cu_mat, texture)
    cu_mat
end

function render_to_sum(program::GLAbstraction.AbstractProgram, scene::Scene, texture::GLAbstraction.Texture, channel::Channel, cu_mat::CuMatrix{Float32})
    draw_task = @task draw_to_cuda(program, scene, texture, cu_mat)
    # Wait until channel rendered the task
    put!(channel, draw_task)
    wait(draw_task)
    # Sync copy, async CUDA
    sum(cu_mat)
end

# Waiting on main task would deadlock
function bench_cuda(program::GLAbstraction.AbstractProgram, scene::Scene, texture::GLAbstraction.Texture, channel::Channel)
    cu_mat = CuMatrix{Float32}(undef, size(texture))
    @sync begin
        Threads.@threads for _ in 1:N_TASKS
            Threads.@spawn begin
                render_to_sum(program, scene, texture, channel, cu_mat)
            end
        end
    end
end

function bench_cpu(program::GLAbstraction.AbstractProgram, scene::Scene, framebuffer::GLAbstraction.FrameBuffer, channel::Channel)
    @sync begin
        Threads.@threads for _ in 1:N_TASKS
            Threads.@spawn begin
                render_to_cpu_sum(program, scene, framebuffer, channel)
            end
        end
    end
end

@benchmark bench_cuda(depth_prog, scene, texture, channel)
@benchmark bench_cpu(depth_prog, scene, framebuffer, channel)

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
