using ModernGL, GLAbstraction, GLFW, SciGL
using CoordinateTransformations, Rotations, StaticArrays

const GLA = GLAbstraction

const WIDTH = 800
const HEIGHT = 600

# Create the window. This sets all the hints and makes the context current.
window = GLFW.Window(name="SciGL.jl test", resolution=(WIDTH, HEIGHT), windowhints=[(GLFW.DEPTH_BITS, 32)])
GLFW.MakeContextCurrent(window)
GLA.set_context!(window)

# General OpenGL config
glClearColor(0,0,0,0)
glClearDepth(0)
glEnable(GL_DEPTH_TEST)
glDepthFunc(GL_LEQUAL)

# Compile shader program
vertex_shader = GLA.vert"""
#version 330 core
in vec3 normal;
in vec3 position;
in vec3 color;

out vec3 model_color;
out vec3 model_normal;
out vec4 view_position;
out vec4 world_position;
out vec3 world_normal;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

void main()
{
    model_color = color;
    model_normal = normal;

    world_normal = normalize(mat3(transpose(inverse(model_matrix))) * normal);
    world_position = model_matrix * vec4(position, 1.0);
    view_position = view_matrix * world_position;
    gl_Position = projection_matrix * view_position;
}
"""

fragment_shader = GLA.frag"""
# version 150

in vec3 model_color;
in vec3 model_normal;
in vec4 view_position;
in vec3 world_normal;
in vec4 world_position;

out vec4 out_color;

void main()
{
    // normal vector as color
    out_color = vec4(world_normal, 1.0);

    // silhouette
    // out_color = vec4(1.0, 1.0, 1.0, 1.0);

    // depth
    // float d = world_position.z;
    // out_color = vec4(1.0, d, d, 1.0);
}
"""

prog = GLA.Program(vertex_shader, fragment_shader)

# Init Model
mesh = MeshModel("examples/meshes/monkey.obj", prog)
object = SceneObject(mesh, prog)
object.pose.t = Translation(0, 0, 0)

# Init Camera
cv_cam = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2)
camera = SceneObject(cv_cam, prog)
camera.pose.t = Translation(2, 2, 2)
camera.pose.R = lookat(camera, object, SVector{3}([0 1 0]))
display(camera.pose.R)

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    glClear(GL_COLOR_BUFFER_BIT)
    to_gpu(camera)
    to_gpu(object)
    draw(object)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
