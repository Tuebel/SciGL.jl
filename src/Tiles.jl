# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 
using ModernGL

"""
    Tiles
For tiled rendering, containing `n_tiles` tiles of `x_tiles`×`y_tiles`. 
Each tile has the dimensions `width`×`height`.
"""
struct Tiles
    tile_width::Int64
    tile_height::Int64
    n_tiles::Int64
    x_tiles::Int64
    y_tiles::Int64
end

"""
    Tiles n_tiles::Int, width::Int, height
For tiled rendering, containing `n` tiles of size `width`×`height`. 
"""
function Tiles(n_tiles::Integer, width::Int, height::Int)
    (x_tiles, y_tiles) = texture_size(n_tiles, width, height)
    Tiles(width, height, n_tiles, x_tiles, y_tiles)
end

"""
    texture_size(n_tiles, width, height)
Calculates the minimal size of a raster to render `n_tiles` of the size `(width, height)`.
"""
function texture_size(n_tiles::Int, width::Int, height::Int)
    max_size = GLAbstraction.glGetIntegerv(GL_MAX_RENDERBUFFER_SIZE)
    max_x = trunc(Int64, max_size / width)
    max_y = trunc(Int64, max_size / height)
    if n_tiles <= 0 || n_tiles > max_x * max_y
        return (0, 0)
    end
    # minimum needed views per column and row (ceil int division)
    min_x = ceil(Int64, n_tiles / max_x)
    min_y = ceil(Int64, n_tiles / min_x)
    (min_x, min_y)
end

"""
    length(tiles)
Number of tiles.
"""
Base.length(tiles::Tiles) = tiles.n_tiles

"""
    size(tiles)
Size of the full rendered image / texture size.
"""
Base.size(tiles::Tiles) = (tiles.x_tiles * tiles.tile_width, tiles.y_tiles * tiles.tile_height)

"""
    tile_length(tiles)
length= width * height of one tile.
"""
tile_length(tiles::Tiles) = tiles.tile_width * tiles.tile_height

"""
    tile_size(tiles)
(width, height) of one tile.
"""
tile_size(tiles::Tiles) = (tiles.tile_width, tiles.tile_height)

"""
    gl_tile_indices(tiles, id)
Calculates the OpenGL indices of the i-th tile.
The number of the tile column / row not the coordinates in the image.
"""
gl_tile_indices(tiles::Tiles, id::Integer) = rem(id - 1, tiles.x_tiles), div(id - 1, tiles.x_tiles)

"""
    tile_indices(tiles, id)
Calculates the Julia indices of the i-th tile.
The number of the tile column / row not the coordinates in the image.
"""
function tile_indices(tiles::Tiles, id::Int)
    x, y = gl_tile_indices(tiles, id)
    x + 1, y + 1
end

"""
    coordinates(tiles, id)
Image coordinates of the upper left tile corner.
"""
function coordinates(tiles::Tiles, id::Integer)
    x, y = gl_tile_indices(tiles, id)
    x0 = x * tiles.tile_width + 1
    y0 = y * tiles.tile_height + 1
    x0, y0
end

"""
    coordinates(tiles, tile_id, iter)
Image coordinates of iter in the whole texture.
`iter` would typically be thread_id:n_threads:width*height
"""
function coordinates(tiles::Tiles, tile_id::Integer, iter::Integer)
    # Upper left corner indices
    tile_left, tile_top = coordinates(tiles, tile_id)
    # Starting 1 is included in the top lef coordinates
    tile_x = rem(iter - 1, tiles.tile_width)
    tile_y = div(iter - 1, tiles.tile_width)
    tile_left + tile_x, tile_top + tile_y
end

"""
    cartesian_idx(tiles, i)
Image coordinates for a linear index `i`.
"""
function cartesian_idx(tiles::Tiles, i::Integer)
    tile_id = (i - 1) ÷ tile_length(tiles) + 1
    iter = (i - 1) % tile_length(tiles) + 1
    coordinates(tiles, tile_id, iter)
end

"""
    CartesianIndex(tiles, i)
Image coordinates for a linear index `i`.
"""
Base.CartesianIndex(tiles::Tiles, i::Integer) = cartesian_idx(tiles, i) |> CartesianIndex

"""
    linear_idx(tiles, i)
Allows to iterate image coordinates as 3D array [x,y,tile] so that every full tile is iterated after each other.
"""
function linear_idx(tiles::Tiles, i::Integer)
    x, y = cartesian_idx(tiles, i)
    width, height = size(tiles)
    width * (y - 1) + x
end

"""
    LinearIndices(tiles)
Allows to iterate image coordinates as 3D array [x,y,tile] so that every full tile is iterated after each other.
"""
function Base.LinearIndices(tiles::Tiles)
    res = Array{Int64}(undef, tile_size(tiles)..., length(tiles))
    for i in 1:length(tiles)*tile_length(tiles)
        res[i] = linear_idx(tiles, i)
    end
    res
    # WARN this just results in 
    #LinearIndices(res)
end

"""
    view(M, tiles, id)
Create a view of the Matrix `M` for the given tile id.
"""
function Base.view(M::AbstractMatrix, tiles::Tiles, id::Int)
    x0, y0 = coordinates(tiles, id)
    x1 = x0 + tiles.tile_width - 1
    y1 = y0 + tiles.tile_height - 1
    view(M, x0:x1, y0:y1)
end

"""
    activate_tile(tiles, id)
Set the viewport and scissors to the given tile id.
"""
function activate_tile(tiles::Tiles, id::Int)
    x, y = gl_tile_indices(tiles, id)
    x0 = x * tiles.tile_width
    y0 = y * tiles.tile_height
    glViewport(x0, y0, tiles.tile_width, tiles.tile_height)
    glScissor(x0, y0, tiles.tile_width, tiles.tile_height)
    glEnable(GL_SCISSOR_TEST)
end

"""
    activate_all(tiles)
Activates the viewport and scissors for all tiles.
"""
function activate_all(tiles::Tiles)
    glViewport(0, 0, size(tiles)...)
    glDisable(GL_SCISSOR_TEST)
end

"""
    unsafe_copyto!(dest, source, tiles)
Convenience dispatch for copying the tile from the GPU source to the CPU dest.
"""
GLAbstraction.unsafe_copyto!(dest, source, tiles::Tiles, id::Integer) = unsafe_copyto!(dest, source, coordinates(tiles, id)...)
