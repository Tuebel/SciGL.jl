using ModernGL, GLAbstraction, GLFW, SciGL
using CoordinateTransformations, Rotations, StaticArrays

const WIDTH = 800
const HEIGHT = 600

# Create the window. This sets all the hints and makes the context current.
window = GLFW.Window(name="SciGL.jl test", resolution=(WIDTH, HEIGHT), windowhints=[(GLFW.DEPTH_BITS, 32)])
GLFW.MakeContextCurrent(window)
GLAbstraction.set_context!(window)

# General OpenGL config
glClearColor(0,0,0,0)
glEnable(GL_DEPTH_TEST)
glDepthFunc(GL_LEQUAL)

# Compile shader program
normal_prog = GLAbstraction.Program(SimpleVert, NormalFrag)
silhouette_prog = GLAbstraction.Program(SimpleVert, SilhouetteFrag)
depth_prog = GLAbstraction.Program(SimpleVert, DepthFrag)

# Init mesh
monkey = load_mesh("examples/meshes/monkey.obj", normal_prog) |> SceneObject

# Init Camera
camera = CvCamera(WIDTH, HEIGHT, 1.2 * WIDTH, 1.2 * HEIGHT, WIDTH / 2, HEIGHT / 2) |> SceneObject

# Draw until we receive a close event
while !GLFW.WindowShouldClose(window)
    # events
    GLFW.PollEvents()
    if GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS
        GLFW.SetWindowShouldClose(window, true)
    end
    # update camera pose
    camera.pose.t = Translation(1.5 * sin(2 * π * time() / 5), 0, 1.5 * cos(2 * π * time() / 5))
    camera.pose.R = lookat(camera, monkey, SVector{3}([0 1 0]))

    # draw
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    if floor(Int, time() / 5) % 3 == 0
        to_gpu(camera,  normal_prog)
        to_gpu(monkey,    normal_prog)
        draw(monkey,      normal_prog)
    elseif floor(Int, time() / 5) % 3 == 1
        to_gpu(camera,  silhouette_prog)
        to_gpu(monkey,    silhouette_prog)
        draw(monkey,      silhouette_prog)
    else
        to_gpu(camera,  depth_prog)
        to_gpu(monkey,    depth_prog)
        draw(monkey,      depth_prog)
    end
    GLFW.SwapBuffers(window)
end

# needed if you're running this from the REPL
GLFW.DestroyWindow(window)
