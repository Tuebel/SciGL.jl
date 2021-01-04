# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

abstract type Camera <: SceneType end

"""
A Camera parametrized like OpenCV.
The convention is as in OpenCV: x-rigth, y-down, **z-forward**
"""
struct CvCamera <: Camera
    # horizontal resolution [pixel]
    width::Integer
    # vertical resolution in [pixel]
    height::Integer
    # horizontal focal length [pixel/m]
    f_x::Real
    # vertical focal length [pixel/m]
    f_y::Real
    # horizontal center offset [pixel]
    c_x::Real
    # vertical center offset [pixel]
    c_y::Real
    # axis skew
    s::Real
    # distortion coefficients
    distortion::SVector{8}
    # near plane for OpenGL
    near::Real
    # far plane for OpenGL
    far::Real
end

"""
Parametrizes the glOrtho camera function.
The convention is as in OpenGL: x-rigth, y-up, **negative z-forward**
"""
struct GLOrthoCamera <: Camera
    left::Integer
    right::Integer
    top::Integer
    bottom::Integer
    near::Real
    far::Real
end

"""
    OrthgraphicCamera(c::CvCamera)
extracts the orthographic scaling from the OpenCV camera
"""
OrthgraphicCamera(c::CvCamera) = GLOrthoCamera(0, c.width, 0, c.height, c.near, c.far)

"""
    orthographic_matrix(c::GLOrthoCamera)
Calculates the orthographic projection matrix like glOrtho
"""
function orthographic_matrix(c::GLOrthoCamera)
    M = zeros(4, 4)
    M[1,1] = 2 / (c.right - c.left)
    M[2,2] = 2 / (c.top - c.bottom)
    M[3,3] = -2 / (c.far - c.near)
    M[1,4] = -(c.right + c.left) / (c.right - c.left)
    M[2,4] = -(c.top + c.bottom) / (c.top - c.bottom)
    M[3,4] = -(c.far + c.near) / (c.far - c.near)
    M[4,4] = 1
    return M
end


"""
    orthographic_matrix(c::GLOrthoCamera)
Calculates the orthographic projection matrix for an OpenCV camera
"""
orthographic_matrix(c::CvCamera) = c |> OrthgraphicCamera |> orthographic_matrix

perspective_matrix(c::CvCamera) = [
    c.f_x   -c.s    -c.c_x          0;
    0       -c.f_y  -c.cy           0;
    0       0       c.near + c.far  c.near * c.far;
    0       0       -1              0;
]

"""
    view_matrix(so::SceneObject{CvCamera})
Calculates the view matrix for a camera pose.
The convention is as in OpenGL: x-rigth, y-up, **negative z-forward**
"""
function view_matrix(so::SceneObject{GLOrthoCamera})
    affine = AffineMap(so.pose)
    passive = inv(affine)
    return Matrix(passive)
end

"""
    view_matrix(so::SceneObject{CvCamera})
Calculates the view matrix for a camera pose.
The convention is as in OpenCV: x-rigth, y-down, **z-forward**
"""
function view_matrix(so::SceneObject{CvCamera})
    # convert camera pose to passive transformation matrix / move the world around the camera
    affine = AffineMap(so.pose)
    passive = inv(affine)
    mat = Matrix(passive)
    # convert camera view direction from OpenCV to OpenGL
    # negate y & z axes -> negate corresponding rows
    # TODO column major?
    mat[2,:] = -mat[2,:]
    mat[3,:] = -mat[3,:]
    return mat
end

"""
    projection_matrix(c::CvCamera)
Calculates the projection matrix an OpenCV camera.
The convention is as in OpenCV: x-rigth, y-down, **z-forward**
"""
projection_matrix(c::CvCamera) = orthographic_matrix(c) * perspective_matrix(c)

"""
    projection_matrix(c::GLOrthoCamera)
Calculates the projection matrix an orthographic OpenGL camera.
The convention is as in OpenGL: x-rigth, y-up, **negative z-forward**
"""
projection_matrix(c::GLOrthoCamera) = orthographic_matrix(c)

"""
    to_gpu(so::SceneObject{Camera})
Transfers the view and projection matrices to the OpenGL program
"""
function to_gpu(so::SceneObject{Camera})
    GLAbstraction.bind(so.program)
    GLAbstraction.gluniform(so.program, :view_matrix, view_matrix(so))
    GLAbstraction.gluniform(so.program, :projection_matrix, projection_matrix(so.object))
    GLAbstraction.unbind(so.program)
end
