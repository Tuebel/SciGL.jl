# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Accessors
using Images
using ImageShow
using SciGL

WIDTH = 801
HEIGHT = 600
DEPTH = 300

# Create the GLFW window. This sets all the hints and makes the context current.
if cuda_interop_available()
    gl_context = color_offscreen_context(WIDTH, HEIGHT, DEPTH, CuArray)
else
    gl_context = color_offscreen_context(WIDTH, HEIGHT, DEPTH, Array)
end

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init scene with normal_prog as it uses most attributes
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * WIDTH, WIDTH / 2, HEIGHT / 2) |> Camera
cube = upload_mesh(normal_prog, "examples/meshes/cube.obj")
@reset cube.pose.translation = Translation(1, 0, 0)
monkey = upload_mesh(normal_prog, "examples/meshes/monkey.obj")
@reset monkey.pose.translation = Translation(0, 0, 0)
scene = Scene(camera, [cube, monkey])

# for gif
fps = 60
# for fps benchmark
n_frames = 200
images = Array{Array{RGB{N0f8},2}}(undef, n_frames)
seconds = @elapsed for frame_number in 1:n_frames
    # events
    GLFW.PollEvents()
    # Camera rotates around mathematically positive Z
    @reset scene.camera.pose.translation = Translation(1.3 * cos(π * frame_number / fps), 1.3 * sin(π * frame_number / fps), 0)
    @reset scene.camera.pose.rotation = lookat(scene.camera, monkey, [0, 0, 1])
    images[frame_number] = transpose(draw(gl_context, scene))
end
println("Average fps: $(n_frames / seconds)")
ImageShow.gif(images; fps=fps) |> display

# needed if you're running this from the REPL
destroy_context(gl_context)
