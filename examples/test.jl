# Here, we illustrate a more "julian" implementation that leverages
# some of the advantages of GLAbstraction
using ModernGL, GLAbstraction, GLFW, SciGL
using CoordinateTransformations, Rotations

const GLA = GLAbstraction

# Create the window. This sets all the hints and makes the context current.
window = GLFW.Window(name="Drawing polygons 5", resolution=(800, 600))
# We assign the created window as the "current" context in GLAbstraction to which all GL objects are "bound", this is to avoid using GL objects in the wrong context, but actually currently no real checks are made except initially that at least there is a context initialized.
# Think of this as a way of bookkeeping.
GLFW.MakeContextCurrent(window)
GLA.set_context!(window)

# The vertex shader---note the `vert` in front of """
vertex_shader = GLA.vert"""
#version 330 core
in vec3 normal;
in vec3 position;
in vec3 color;

out vec3 frag_color;
out vec3 world_normal;
out vec4 world_position;

uniform mat4 model_matrix;
// uniform mat4 projection_matrix;
// uniform mat4 view_matrix;

void main()
{
  world_normal = normalize(mat3(transpose(inverse(model_matrix))) * normal);
  
  world_position = model_matrix * vec4(position, 1.0);
  // vec4 view_pos  = view_matrix * world_position;
  // TODO
  gl_Position = world_position;
  // gl_Position = projection_matrix * view_pos;


  // TODO
  // frag_color = color;
  frag_color = normal;
}
"""

# The fragment shader
fragment_shader = GLA.frag"""
# version 150

in vec3 frag_color;
in vec3 world_normal;
in vec3 world_position;

out vec4 out_color;

void main()
{
    out_color = vec4(frag_color, 1.0);
}
"""

# First we combine these two shaders into the program that will be used to render
prog = GLA.Program(vertex_shader, fragment_shader)

# Now we load the model
model = Model3D("examples/meshes/cube.obj", prog)

# Default pose
t = Translation(0.3, -0.2, 0)
r = UnitQuaternion(1, 0, 0, 0)
R = LinearMap(r)
# Active: rotate then translate
pose = t ∘ R

# Draw until we receive a close event
glClearColor(0,0,0,0)
while !GLFW.WindowShouldClose(window)
    glClear(GL_COLOR_BUFFER_BIT)
    draw(model, pose)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
end
GLFW.DestroyWindow(window)  # needed if you're running this from the REPL
