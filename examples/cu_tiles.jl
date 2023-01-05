# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using CUDA
using SciGL

tiles = Tiles(3, 2, 4, 2, 2)
mat = CuMatrix{Int64}(undef, size(tiles))

THREADS = 128
BLOCKS = length(tiles)
SHMEM = THREADS * sizeof(Float32)

# TODO how to stride the iterator
function coordinate_test(mat::CuDeviceMatrix, tiles::Tiles)
    thread_id = threadIdx().x
    block_id = blockIdx().x
    n_threads = blockDim().x
    image_length = tile_length(tiles)
    for i = thread_id:n_threads:image_length
        x, y = tile_coordinates(tiles, block_id, i)
        @inbounds mat[x, y] = i * block_id
    end
    return nothing
end
@cuda threads = THREADS blocks = BLOCKS shmem = SHMEM coordinate_test(mat, tiles)
mat
