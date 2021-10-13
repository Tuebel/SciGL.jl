# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

"""
Set the context as current in GLFW and GLAbstractions
"""
function set_context(window::GLFW.Window)
    GLFW.MakeContextCurrent(window)
    GLAbstraction.set_context!(window)
    return window
end

# I find most of the GLFW defaults more reasonable than the ones provided by GLFW.jl
const default_window_hints = [
    (GLFW.RESIZABLE, false),
    (GLFW.FOCUSED, false)
    ]

"""
Create an OpenGL context in fullscreen mode and makes it current.
"""
context_fullscreen(width::Integer, height::Integer; name="SciGL.jl", window_hints=default_window_hints) = GLFW.Window(name=name, resolution=(width, height), windowhints=window_hints, fullscreen=true) |> set_context

"""
Create an OpenGL context which is not visible, e.g. for offscreen rendering and makes it current.
"""
context_offscreen(width::Integer, height::Integer; name="SciGL.jl", window_hints=default_window_hints) = GLFW.Window(name=name, resolution=(width, height), windowhints=window_hints, visible=false) |> set_context

"""
Create an OpenGL context in windowed mode and makes it current.
"""
context_window(width::Integer, height::Integer; name="SciGL.jl", window_hints=default_window_hints) = GLFW.Window(name=name, resolution=(width, height), windowhints=window_hints, focus=true) |> set_context

"""
Enable depth and stencil testing
"""
function enable_depth_stencil()
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)
    glEnable(GL_STENCIL_TEST)
end

"""
Set a color which is used for glClear(GL_COLOR_BUFFER_BIT), default is black
"""
function set_clear_color(color::AbstractRGBA=RGBA(0, 0, 0, 0))
    glClearColor(red(color), green(color), blue(color), alpha(color))
end

"""
Clears color, depth, and stencil.
"""
function clear_buffers()
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
end