# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.
using GLAbstraction
using ModernGL

"""
    activate_layer(tiles, id)
Activates `layer` of the first attachement to `framebuffer`.
Does not for RBOs since they are inherently 2D.
"""
function activate_layer(framebuffer::GLAbstraction.FrameBuffer, layer::Int)
    # SciGL only uses the first attachment
    texture = first(GLAbstraction.color_attachments(framebuffer))
    if layer > texture |> size |> last
        @error "Cannot activate layer $layer, texture size $(size(texture))"
        return
    end
    # C starts counting at 0 → layer-1
    glFramebufferTextureLayer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, texture.id, 0, layer - 1)
end
