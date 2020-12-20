# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2020, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

# Multi Stage Build: First pull julia image and copy the artifacts to the cudagl image
FROM julia:buster AS julia_img

# CudaGL
FROM nvidia/cudagl:11.0-devel-ubuntu20.04
ENV JULIA_PATH /usr/local/julia
ENV PATH $JULIA_PATH/bin:$PATH
COPY --from=julia_img $JULIA_PATH $JULIA_PATH

# dev tools
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
RUN apt-get update && apt-get install -y curl git git-lfs
