# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2020, Tim Redick
# All rights reserved. 

# Multi Stage Build: First pull julia image and copy the artifacts to the cudagl image
FROM julia:buster AS julia_img

# CudaGL
FROM nvidia/opengl:1.2-glvnd-devel
ENV JULIA_PATH /usr/local/julia
ENV PATH $JULIA_PATH/bin:$PATH
COPY --from=julia_img $JULIA_PATH $JULIA_PATH

# dev tools
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
RUN apt-get update && apt-get install -y curl git git-lfs

# Non-root-user to avoid file permission problems
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
USER $USERNAME

# IJUlia for non-root user
RUN curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh \
    && sh /tmp/miniconda.sh -b -p /home/vscode/miniconda \
    && rm /tmp/miniconda.sh
ENV PATH="/home/vscode/miniconda/bin:${PATH}"
RUN conda init bash
RUN conda install -c conda-forge -y jupyterlab 
COPY install_packages.jl /tmp/install_packages.jl
RUN julia /tmp/install_packages.jl

# Convenient Julia packages and config
COPY install_packages.jl /tmp/install_packages.jl
COPY startup.jl /home/vscode/.julia/config/startup.jl
RUN julia /tmp/install_packages.jl
