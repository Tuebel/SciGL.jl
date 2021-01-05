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
prog = GLA.Program(SimpleVert, NormalFrag)

# Init Model
mesh = MeshModel("examples/meshes/cube.obj", prog)
object = SceneObject(mesh, prog)
object.pose.t = Translation(0, 0, 0)

# Init Camera
cv_cam = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2)
camera = SceneObject(cv_cam, prog)
camera.pose.t = Translation(1, 1, 1)
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
