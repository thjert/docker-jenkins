FROM jenkins:2.60.3
###FROM jenkins:1.642.1
MAINTAINER Justin Menga <justin.menga@gmail.com>

# Suppress apt installation warnings
ENV DEBIAN_FRONTEND=noninteractive

# Change to root user
USER root

# Used to set the docker group ID
# Set to 999 by default, which is the group ID used by AWS Linux ECS Instance
ARG DOCKER_GID=999

# Create Docker Group with GID
# Set default value of 497 if DOCKER_GID set to blank string by Docker Compose
RUN groupadd -g ${DOCKER_GID:-497} docker

# Used to control Docker and Docker Compose versions installed
# NOTE: As of February 2016, AWS Linux ECS only supports Docker 1.9.1
ARG DOCKER_ENGINE=1.10.2
ARG DOCKER_COMPOSE=1.6.2
###ARG DOCKER_OPTS="-H tcp://0.0.0.0:2375"
###ARG DOCKER_OPTS="-H unix:///var/run/docker.sock"

# Install base packages
RUN apt-get update -y && \
    apt-get install nodejs -y && \
    apt-get install apt-transport-https curl python-dev python-setuptools gcc make libssl-dev -y && \
    easy_install pip
# First, add the GPG key for the official Docker repository to the system:

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Add the Docker repository to APT sources:
# Command below is required to be able to reach add-apt-repository

RUN apt-get install -y software-properties-common -y


RUN lsb_release -cs
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

#RUN /usr/bin/add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu stretch stable"

# Install Docker Engine
RUN apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | tee /etc/apt/sources.list.d/docker.list && \
    apt-get update -y && \
    apt-cache policy docker-ce && \
    apt-get purge lxc-docker* -y && \
    apt-get install aufs-tools -y && \
    apt-get install cgroupfs-mount -y && \
    apt-get install apparmor -y && \
    apt-get install docker-ce -y && \
    apt-get install net-tools -y && \
    apt-get install yubico-piv-tool -y && \
    usermod -aG docker jenkins && \
    usermod -aG users jenkins

# Install Docker Compose
RUN pip install docker-compose==${DOCKER_COMPOSE:-1.6.2} && \
    pip install ansible boto boto3

################################################################################################################################### 
### Pga Request.callback (/app/node_modules/superagent/lib/node/index.js:698:17 provar jag installera detta.
################################################################################################################################### 
###
# update the repository sources list
# and install dependencies
# replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apt-get update \
    && apt-get install -y curl \
    && apt-get -y autoclean

# nvm environment variables
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 4.4.7

# install nvm
# https://github.com/creationix/nvm#install-script
RUN curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.2/install.sh | bash

# install node and npm
RUN source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# add node and npm to path so the commands are available
ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# confirm installation
RUN node -v
RUN nodejs -v
RUN npm -v
################################################################################################################################### 
###RUN apt-get install npm
RUN npm install superagent

# Kopiera ut group-filen ... Filen med 497 som GID för docker låg kvar

COPY group /etc/group

# Start dockerd due to error when running build from Jenkins
RUN mkdir /etc/systemd/system/docker.service.d
COPY docker.conf /etc/systemd/system/docker.service.d/docker.conf
COPY default-docker /etc/default/docker
RUN systemctl enable docker.service
RUN service docker start
###RUN /etc/init.d/docker start
RUN systemctl list-unit-files

###Funkar ej
###RUN wget http://localhost:8080/cli
###RUN wget http://192.168.56.1:8080/jnlpJars/jenkins-cli.jar

# Change to jenkins user
USER jenkins

# Add Jenkins plugins
COPY plugins.txt /usr/share/jenkins/plugins.txt
###RUN /usr/local/bin/install-plugins.sh /usr/share/jenkins/plugins.txt
###Script finns inte i 1.642.1
###RUN cat /usr/local/bin/install-plugins.sh
RUN /usr/local/bin/install-plugins.sh `cat /usr/share/jenkins/plugins.txt`
###RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt
