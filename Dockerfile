##############################################################################
##                                 Base Image                               ##
##############################################################################
ARG ROS_DISTRO=foxy
FROM ros:$ROS_DISTRO-ros-base
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN rosdep update --rosdistro $ROS_DISTRO

# Update packages only if necessary, ~250MB
# RUN apt update && apt -y dist-upgrade

##############################################################################
##                                 Global Dependecies                       ##
##############################################################################
RUN apt-get update && apt-get install --no-install-recommends -y \
    ros-$ROS_DISTRO-cv-bridge \
    python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# New versions necessary to prevent "skbuild" error from scikit-build
RUN python3 -m pip install -U pip setuptools
RUN pip3 install opencv-contrib-python

##############################################################################
##                                 Create User                              ##
##############################################################################
ARG USER=docker
ARG PASSWORD=petra
ARG UID=1000
ARG GID=1000
ARG DOMAIN_ID=8
ENV UID=$UID
ENV GID=$GID
ENV USER=$USER
ENV ROS_DOMAIN_ID=$DOMAIN_ID
RUN groupadd -g "$GID" "$USER"  && \
    useradd -m -u "$UID" -g "$GID" --shell $(which bash) "$USER" -G sudo && \
    echo "$USER:$PASSWORD" | chpasswd && \
    echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudogrp
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> /etc/bash.bashrc

USER $USER 
RUN mkdir -p /home/$USER/ros2_ws/src

##############################################################################
##                                 User Dependecies                         ##
##############################################################################
WORKDIR /home/$USER/ros2_ws/src
# Access tokens in petra_docker/README.md 
RUN git clone --depth 1 -b v1.0.0 https://github.com/AndreasZachariae/openpose_ros.git
RUN rm -r openpose_ros/openpose_ros
RUN git clone --depth 1 -b 2.0.0 https://github.com/christianrauch/apriltag_msgs.git
RUN git clone --depth 1 -b v1.0.0 https://project_55_bot:glpat-DjsyN_ixYnq-duDb_Sip@www.w.hs-karlsruhe.de/gitlab/iras/research-projects/petra/petra_interfaces.git
RUN git clone --depth 1 -b v1.0.0 https://project_111_bot:glpat-3-6z2gfx2uaEoy1Z2dpq@www.w.hs-karlsruhe.de/gitlab/iras/common/point_transformation.git
# Only COPY build environment for developement. For final version use git clone as above.
COPY . ./petra_patient_monitoring

##############################################################################
##                                 Build ROS and run                        ##
##############################################################################
WORKDIR /home/$USER/ros2_ws
RUN . /opt/ros/$ROS_DISTRO/setup.sh && colcon build --symlink-install
RUN echo "source /home/$USER/ros2_ws/install/setup.bash" >> /home/$USER/.bashrc

RUN sudo sed --in-place --expression \
    '$isource "/home/$USER/ros2_ws/install/setup.bash"' \
    /ros_entrypoint.sh

# CMD ["ros2", "launch", "petra_patient_monitoring", "monitoring.launch.py"]
