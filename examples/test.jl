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

uniform mat3 model_M;
uniform vec3 model_v;
// uniform mat3 view_M;
// uniform vec3 view_v;
// uniform mat4 projection_matrix;

out vec3 world_normal;
out float depth;
out vec3 world_position;

// TODO replace
out vec3 color;

void main()
{
  // normals in world coordinates
  // TODO replace with model_M & model_v
  // world_normal = normalize(mat3(transpose(inverse(model_matrix))) * normal);
  color = normal;
  
  // As in CoordinateTransformations.AffineMaps
  vec3 world_pos = model_M * position + model_v;
  // vec3 view_pos  = view_M * world_position + view_v;
  // gl_Position = projection_matrix * view_pos;
  gl_Position = vec4(world_pos, 1.0);
  // gl_Position = vec4(position, 1.0);

  // for depth rendering in fragement shader
  // depth = view_pos.z;
}
"""

# The fragment shader
fragment_shader = GLA.frag"""
# version 150

in vec3 color;

out vec4 outColor;

void main()
{
    outColor = vec4(color, 1.0);
}
"""

# First we combine these two shaders into the program that will be used to render
prog = GLA.Program(vertex_shader, fragment_shader)

# Now we load the model
model = Model3D("examples/meshes/cube.obj", prog)

# Default pose
t = Translation(0.5, 0, 0)
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
