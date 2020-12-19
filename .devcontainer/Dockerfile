# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2020, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

FROM nvidia/cudagl:11.0-devel-ubuntu20.04
# basic installation
RUN apt-get update && apt-get install julia -y
# dev tools
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
RUN apt-get update && apt-get install -y curl git git-lfs
# https://code.visualstudio.com/docs/remote/containers-advanced#_adding-a-nonroot-user-to-your-dev-container
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
