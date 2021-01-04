module SciGL

greet() = print("Hello World!")

# Export types
export Model3D

# Export functions
export draw
export to_gpu

include("Model3D.jl")
include("Pose.jl")

end # module
