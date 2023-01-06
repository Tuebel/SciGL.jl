# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2023, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using SciGL

# Create the GLFW window. This sets all the hints and makes the context current.
WIDTH = 800
HEIGHT = 600
DEPTH = 10

context = depth_offscreen_context(WIDTH, HEIGHT, DEPTH, Array)

@test context.render_data isa Array{Float32}
# TODO draw a scene

destroy_context(context)
