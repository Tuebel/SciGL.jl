# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

"""
Pipe two return values
"""
Base.:|>(x,y,f) = f(x, y)

"""
Pretty print texture
"""
function Base.show(io::IO, t::GLAbstraction.Texture{T,D}) where {T,D}
    println(io, "Texture$(D)D: ")
    println(io, "                  ID: ", t.id)
    println(io, "                  Size: Dimensions: $(size(t))")
    println(io, "    Julia pixel type: ", T)
    println(io, "   OpenGL pixel type: ", GLENUM(t.pixeltype).name)
    println(io, "              Format: ", GLENUM(t.format).name)
    println(io, "     Internal format: ", GLENUM(t.internalformat).name)
    println(io, "          Parameters: ", t.parameters)
end

"""
Pretty print texture
"""
Base.display(t::GLAbstraction.Texture{T,D}) where {T,D} = Base.show(stdout, t)

"""
Pretty print framebuffer
"""
function Base.show(io::IO, f::GLAbstraction.FrameBuffer{ET,Internals}) where {ET,Internals}
    println(io, "Framebuffer: ")
    println(io, "                  ID: ", f.id)
    for a in f.attachments
        println()
        show(io, a)
    end
end

"""
Pretty print framebuffer
"""
Base.display(f::GLAbstraction.FrameBuffer{ET,Internals}) where {ET,Internals} = Base.show(stdout, f)
