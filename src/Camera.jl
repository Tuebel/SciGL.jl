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
Constructor with reasonable defaults
"""
CvCamera(width::Integer, height::Integer, f_x::Real, f_y::Real, c_x::Real, c_y::Real; s=0, distortion=zeros(8), near=0.01, far=100) = CvCamera(width, height, f_x, f_y, c_x, c_y, s, distortion, near, far)

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
orthographic_matrix(c::GLOrthoCamera) = SMatrix{4,4,Float32}([
    2 / (c.right - c.left)     0       0       -(c.right + c.left) / (c.right - c.left);
    0       2 / (c.top - c.bottom)     0       -(c.top + c.bottom) / (c.top - c.bottom);
    0       0       -2 / (c.far - c.near)       -(c.far + c.near) / (c.far - c.near);
    0       0       0       1;
])

"""
    orthographic_matrix(c::GLOrthoCamera)
Calculates the orthographic projection matrix for an OpenCV camera
"""
orthographic_matrix(c::CvCamera) = c |> OrthgraphicCamera |> orthographic_matrix

perspective_matrix(c::CvCamera) = SMatrix{4,4,Float32}([
    c.f_x   -c.s    -c.c_x          0;
    0       -c.f_y  -c.c_y          0;
    0       0       c.near + c.far  c.near * c.far;
    0       0       -1              0;
])

"""
    view_matrix(so::SceneObject{CvCamera})
Calculates the view matrix for a camera pose.
The convention is as in OpenGL: x-rigth, y-up, **negative z-forward**
"""
function view_matrix(so::SceneObject{GLOrthoCamera})
    affine = AffineMap(so.pose)
    passive = inv(affine)
    return SMatrix{4,4,Float32}(passive)
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
    mat = passive |> SMatrix |> MMatrix{4,4}
    # convert camera view direction from OpenCV to OpenGL
    # negate y & z axes -> negate corresponding rows
    mat[2,:] = -mat[2,:]
    mat[3,:] = -mat[3,:]
    return SMatrix{4,4,Float32}(mat)
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
    lookat(camera, object, up)
Calculates the Rotation to look at the object along positive z with up defining the upwards direction
"""
function lookat_opencv(camera::Pose, object::Pose, up::SVector{3})
    cam_t = SVector{3}(camera.t.translation)
    object_t = SVector{3}(object.t.translation)
    # OpenCV: look along positive z
    z = normalize(object_t - cam_t)
    x = normalize(cross(z, up))
    y = normalize(cross(z, x))
    return RotMatrix3{Float32}([x y z])
end

"""
    lookat(camera, object, up)
Calculates the Rotation to look at the object along negative z with up defining the upwards direction
"""
function lookat_opengl(camera::Pose, object::Pose, up::SVector{3})
    cam_t = SVector{3}(camera.t.translation)
    object_t = SVector{3}(object.t.translation)
    # OpenGL: look along positive z
    z = normalize(cam_t - object_t)
    x = normalize(cross(up, z))
    y = normalize(cross(z, x))
    return RotMatrix3{Float32}([
        transpose(x);
        transpose(y);
        transpose(z);
    ])
end

"""
    lookat(camera, object, up)
Calculates the Rotation to look at the object along positive z with up defining the upwards direction
"""
lookat(camera::SceneObject{CvCamera}, object::SceneObject, up::SVector{3}) = lookat_opencv(camera.pose, object.pose, up)


"""
    lookat(camera, object, up)
Calculates the Rotation to look at the object along negative z with up defining the upwards direction
"""
lookat(camera::SceneObject{GLOrthoCamera}, object::SceneObject, up::SVector{3}) = lookat_opengl(camera.pose, object.pose, up)

"""
    to_gpu(so::SceneObject{Camera})
Transfers the view and projection matrices to the OpenGL program
"""
function to_gpu(so::SceneObject{T}) where {T <: Camera}
    GLAbstraction.bind(so.program)
    GLAbstraction.gluniform(so.program, :view_matrix, view_matrix(so))
    GLAbstraction.gluniform(so.program, :projection_matrix, projection_matrix(so.object))
    GLAbstraction.unbind(so.program)
end


const WIDTH = 800
const HEIGHT = 600
cv_cam = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2)
