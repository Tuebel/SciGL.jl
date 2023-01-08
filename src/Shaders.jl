# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2021, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

DepthFrag = GLAbstraction.frag"""
# version 150

in vec4 view_position;

out vec4 out_color;

void main()
{
    float d = -1 * view_position.z;
    out_color = vec4(d, d, d, 1.0);
}
"""

DistanceFrag = GLAbstraction.frag"""
# version 150

in vec4 view_position;

out vec4 out_color;

void main()
{
    vec3 center_dist = vec3(view_position);
    float dist = sqrt(dot(center_dist, center_dist));
    out_color = vec4(dist, dist, dist, 1.0);
}
"""

NormalFrag = GLAbstraction.frag"""
# version 150
in vec3 view_normal;

out vec4 out_color;

void main()
{
    out_color = vec4(view_normal, 1.0);
}
"""

ModelNormalFrag = GLAbstraction.frag"""
# version 150
in vec3 model_normal;

out vec4 out_color;

void main()
{
    out_color = vec4(model_normal, 1.0);
}
"""

SilhouetteFrag = GLAbstraction.frag"""
# version 150

out vec4 out_color;

void main()
{
    out_color = vec4(1.0, 1.0, 1.0, 1.0);
}
"""

SimpleVert = GLAbstraction.vert"""
#version 330 core
in vec3 normal;
in vec3 position;
in vec3 color;

out vec3 model_color;

out vec3 model_normal;
out vec3 world_normal;
out vec3 view_normal;

out vec4 model_position;
out vec4 view_position;
out vec4 world_position;

uniform mat4 model_matrix;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;

void main()
{
    model_color = color;

    model_normal = normal;
    // Assumption: orthogonal matrices A^-1^T = A
    world_normal = normalize(mat3(model_matrix) * model_normal);
    view_normal = normalize(mat3(view_matrix) * world_normal);

    model_position = vec4(position, 1.0);
    world_position = model_matrix * model_position;
    view_position = view_matrix * world_position;
    gl_Position = projection_matrix * view_position;
}
"""