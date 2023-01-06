# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

"""
    set_context!(window)
Use this context for the current thread.
"""
function set_context!(window::GLFW.Window)
    GLFW.MakeContextCurrent(window)
    GLAbstraction.set_context!(window)
    @info "OpenGL version: $(unsafe_string(glGetString(GL_VERSION)))"
    return window
end

"""
    context_fullscreen(width, height; name, window_hints)
Create an OpenGL context in fullscreen mode and makes it current.
"""
context_fullscreen(width::Integer, height::Integer; name="SciGL.jl", window_hints=default_window_hints) = GLFW.Window(name=name, resolution=(width, height), windowhints=window_hints, fullscreen=true) |> render_defaults |> set_context!

"""
    context_offscreen(width, height; name, window_hints)
Create an OpenGL context which is not visible, e.g. for offscreen rendering and makes it current.
"""
context_offscreen(width::Integer, height::Integer; name="SciGL.jl", window_hints=default_window_hints) = GLFW.Window(name=name, resolution=(width, height), windowhints=window_hints, visible=false) |> render_defaults |> set_context!

"""
    context_window(width, height; name, window_hints)
Create an OpenGL context in windowed mode and makes it current.
"""
context_window(width::Integer, height::Integer; name="SciGL.jl", window_hints=default_window_hints) = GLFW.Window(name=name, resolution=(width, height), windowhints=window_hints, focus=true) |> render_defaults |> set_context!

# I find most of the GLFW defaults more reasonable than the ones provided by GLFW.jl
const default_window_hints = [
    (GLFW.RESIZABLE, false),
    (GLFW.FOCUSED, false),
    (GLFW.CONTEXT_VERSION_MAJOR, 4),
    # Persistent mapping & glGetTextureSubImage
    (GLFW.CONTEXT_VERSION_MINOR, 5),
    (GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)]

# Pipeable, set some sane defaults to avoid black screens by default
function render_defaults(x)
    enable_depth_stencil()
    set_clear_color()
    clear_buffers()
    return x
end

"""
    enable_depth_stencil()
Enable depth and stencil testing
"""
function enable_depth_stencil()
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)
    glEnable(GL_STENCIL_TEST)
end

"""
    set_clear_color(color)
Set a color which is used for glClear(GL_COLOR_BUFFER_BIT), default is black
"""
function set_clear_color(color::AbstractRGBA=RGBA(0, 0, 0, 1))
    glClearColor(red(color), green(color), blue(color), alpha(color))
end

"""
    clear_buffers()
Clears color, depth, and stencil.
"""
function clear_buffers()
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)
end