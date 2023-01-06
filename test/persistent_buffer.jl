# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2023, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using SciGL

# Create the GLFW window. This sets all the hints and makes the context current.
WIDTH = 800
HEIGHT = 600
window = context_offscreen(WIDTH, HEIGHT)

# Color
framebuffer = color_framebuffer(WIDTH, HEIGHT, 3)
texture = first(color_attachments(framebuffer))
pbo = @inferred PersistentBuffer(texture)
@test eltype(pbo) <: RGBA
array = Array(pbo)

# Depth should return Float32
framebuffer = depth_framebuffer(WIDTH, HEIGHT, 3)
texture = first(color_attachments(framebuffer))
pbo = @inferred PersistentBuffer(texture)
@test eltype(pbo) == Float32

destroy_context(window)