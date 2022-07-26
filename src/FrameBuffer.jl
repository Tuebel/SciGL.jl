# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using ColorTypes

"""
    color_framebuffer(dims::Integer...)
Simplified construction of a FrameBuffer which can be used for offscreen rendering of RGB color images.
Supports depth and stencil tests via an appropriate RenderBuffer.
"""
function color_framebuffer(dims::Integer...)
    width, height, _... = dims
    # RGB causes weird bug for some resolutions, e.g. 800x600 works 801x600 not
    color_tex = GLAbstraction.Texture(RGBA{N0f8}, dims)
    depth_stencil_rbo = GLAbstraction.RenderBuffer(GLAbstraction.DepthStencil{GLAbstraction.Float24,N0f8}, (width, height))
    GLAbstraction.FrameBuffer((width, height), color_tex, depth_stencil_rbo)
end

"""
    color_framebuffer_rbo(width::Integer, height::Integer)
Simplified construction of a FrameBuffer which can be used for offscreen rendering of RGB color images.
Uses a RenderBuffer instead of a texture.
Supports depth and stencil tests via an appropriate RenderBuffer.
"""
function color_framebuffer_rbo(width::Integer, height::Integer)
    # RGB causes weird bug for some resolutions, e.g. 800x600 works 801x600 not
    color_rbo = GLAbstraction.RenderBuffer(RGBA{N0f8}, (width, height))
    depth_stencil_rbo = GLAbstraction.RenderBuffer(GLAbstraction.DepthStencil{GLAbstraction.Float24,N0f8}, (width, height))
    GLAbstraction.FrameBuffer((width, height), color_rbo, depth_stencil_rbo)
end

"""
    depth_framebuffer(dims::Integer...)
Simplified construction of a FrameBuffer which can be used for offscreen rendering of Float32 depth images.
Supports depth and stencil tests via an appropriate RenderBuffer.
"""
function depth_framebuffer(dims::Integer...)
    width, height, _... = dims
    depth_tex = GLAbstraction.Texture(Gray{Float32}, dims)
    depth_stencil_rbo = GLAbstraction.RenderBuffer(GLAbstraction.DepthStencil{GLAbstraction.Float24,N0f8}, (width, height))
    GLAbstraction.FrameBuffer((width, height), depth_tex, depth_stencil_rbo)
end

"""
    depth_framebuffer_rbo(width::Integer, height::Integer)
Simplified construction of a FrameBuffer which can be used for offscreen rendering of Float32 depth images.
Uses a RenderBuffer instead of a texture.
Supports depth and stencil tests via an appropriate RenderBuffer.
"""
function depth_framebuffer_rbo(width::Integer, height::Integer)
    depth_rbo = GLAbstraction.RenderBuffer(Gray{Float32}, size)
    depth_stencil_rbo = GLAbstraction.RenderBuffer(GLAbstraction.DepthStencil{GLAbstraction.Float24,N0f8}, (width, height))
    GLAbstraction.FrameBuffer((width, height), depth_rbo, depth_stencil_rbo)
end