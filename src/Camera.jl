# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

"""
    view_matrix(so::SceneObject{<:AbstractCamera})
Calculates the view matrix for a camera pose.
The convention is as in OpenCV: x-rigth, y-down, **z-forward**
"""
function view_matrix(camera::SceneObject{<:AbstractCamera})
    # convert camera pose to passive transformation matrix / move the world around the camera
    affine = AffineMap(camera.pose)
    passive = inv(affine)
    mat = passive |> SMatrix |> MMatrix{4,4}
    # convert camera view direction from OpenCV to OpenGL
    # negate y & z axes -> negate corresponding rows
    mat[2, :] = -mat[2, :]
    mat[3, :] = -mat[3, :]
    return SMatrix{4,4,Float32}(mat)
end

# Often, the camera parameters do not change and even its pose might be static. It might be tempting to store the state of the program and camera to avoid frequent uploads. But it is hard to implement type stable which eats up a lot of the performance gains.
"""
    to_gpu(program, scene_camera)
Transfers the view and projection matrices to the OpenGL program
"""
function to_gpu(program::GLAbstraction.AbstractProgram, scene_camera::SceneObject{<:AbstractCamera})
    GLAbstraction.bind(program)
    GLAbstraction.gluniform(program, :view_matrix, view_matrix(scene_camera))
    GLAbstraction.gluniform(program, :projection_matrix, projection_matrix(scene_camera.object))
    GLAbstraction.unbind(program)
end

"""
    CvCamera
A Camera parametrized like OpenCV.
The convention is as in OpenCV: x-right, **y-down**, **z-forward**.
Construct a `Camera` from it to be used in the shaders
"""
struct CvCamera
    # horizontal resolution [pixel]
    width::Int
    # vertical resolution in [pixel]
    height::Int
    # horizontal focal length [pixel/m]
    f_x::Float32
    # vertical focal length [pixel/m]
    f_y::Float32
    # horizontal center offset [pixel]
    c_x::Float32
    # vertical center offset [pixel]
    c_y::Float32
    # axis skew
    s::Float32
    # distortion coefficients
    distortion::SVector{8}
    # near plane for OpenGL
    near::Float32
    # far plane for OpenGL
    far::Float32
end

"""
    CvCamera(width, height, f_x, f_y, c_x, c_y; [s=0, distortion=zeros(8), near=0.01, far=100])
Constructor with reasonable defaults
# Parameters
* width horizontal resolution [pixel]
* height: vertical resolution in [pixel]
* f_x: horizontal focal length [pixel/m]
* f_y: vertical focal length [pixel/m]
* c_x: horizontal center offset [pixel]
* c_y: vertical center offset [pixel]
* s: axis skew
* distortion: distortion coefficients
* near: near plane for OpenGL
* far: far plane for OpenGL
"""
CvCamera(width, height, f_x, f_y, c_x, c_y; s=0, distortion=zeros(8), near=0.01, far=100) = CvCamera(width, height, f_x, f_y, c_x, c_y, s, distortion, near, far)

"""
    perspective_matrix(cv_camera)
Generate the perspective transformation matrix from the OpenCV camera parameters.
Takes care of the OpenGL vs. OpenCV convention:
* looking down negative Z vs. positive Z
* up in image is positive Y vs. negative Y
Thus, use the OpenCV convention in following steps.
"""
perspective_matrix(c::CvCamera) = @SMatrix Float32[
    c.f_x -c.s -c.c_x 0
    0 -c.f_y -c.c_y 0
    0 0 c.near+c.far c.near*c.far
    0 0 -1 0
]

"""
    GLOrthographicCamera
Parametrizes an OrthographicCamera which transforms a cuboid space with the given parameters ([left,bottom,near],[right,top,far]) to normalized device coordinates ([-1,-1,-1],[1,1,1]).
"""
struct OrthographicCamera
    left::Int
    right::Int
    top::Int
    bottom::Int
    near::Float32
    far::Float32
end

"""
    OrthographicCamera(c::CvCamera)
Extracts the orthographic scaling from the OpenCV camera.
Since the origin in OpenGL is in the bottom-left and in OpenCV in the top-left, images will appear upside down in the OpenGL window but upright in memory.
"""
OrthographicCamera(c::CvCamera) = OrthographicCamera(0, c.width, c.height, 0, c.near, c.far)

"""
    orthographic_matrix(c::GLOrthoCamera)
Calculates the orthographic projection matrix like glOrtho
"""
orthographic_matrix(c::OrthographicCamera) = @SMatrix Float32[
    2/(c.right-c.left) 0 0 -(c.right + c.left)/(c.right-c.left)
    0 2/(c.top-c.bottom) 0 -(c.top + c.bottom)/(c.top-c.bottom)
    0 0 -2/(c.far-c.near) -(c.far + c.near)/(c.far-c.near)
    0 0 0 1
]

"""
    lookat(camera_t, object_t, [up=[0,-1.0]])
Calculates the Rotation to look at the object along positive Z with up defining the upwards direction.
Default is the OpenCV convention: up = negative Y.
"""
function lookat(camera_t, object_t, up=SVector{3}(0, -1, 0))
    c_t = SVector{3}(camera_t)
    o_t = SVector{3}(object_t)
    u = SVector{3}(up)
    # OpenCV: look along positive z
    z = normalize(o_t - c_t)
    x = normalize(cross(z, u))
    y = normalize(cross(z, x))
    return RotMatrix3{Float32}([x y z])
end


lookat(camera_t::Translation, object_t::Translation, up=SVector{3}(0, -1, 0)) = lookat(camera_t.translation, object_t.translation, up)

lookat(camera::Pose, object::Pose, up=SVector{3}(0, -1, 0)) = lookat(camera.translation, object.translation, up)

lookat(camera::SceneObject{<:AbstractCamera}, object::SceneObject, up=SVector{3}(0, -1, 0)) = lookat(camera.pose, object.pose, up)

"""
    Camera
Strongly typed camera type which contains a static projection matrix.
"""
struct Camera <: AbstractCamera
    projection_matrix::SMatrix{4,4,Float32}
end

"""
    Camera(cv_camera, [orthographic_camera=OrthographicCamera(cv_camera)])
Creates a SceneObject{Camera} which contains the projection matrix of the cv_camera.
Optionally a custom orthographic_camera can be provided, e.g. for cropping views.
"""
Camera(cv_camera::CvCamera, orthographic_camera::OrthographicCamera=OrthographicCamera(cv_camera)) = orthographic_matrix(orthographic_camera) * perspective_matrix(cv_camera) |> Camera |> SceneObject

"""
    crop(cv_camera, left, top, width, height)
Creates a SceneObject{Camera} which contains the projection matrix of the cv_camera.
This camera does not render the full size image of the cv_camera but only the area described by the bounding box (left, top, width, height) → ([left, top],[left+width, top+height]).
"""
crop(cv_camera::CvCamera, left, top, width, height) = Camera(cv_camera, OrthographicCamera(left, left + width, top + height, top, cv_camera.near, cv_camera.far))

# AbstractCamera interface
projection_matrix(camera::Camera) = camera.projection_matrix
