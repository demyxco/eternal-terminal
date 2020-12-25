FROM alpine

LABEL sh.demyx.image        demyx/eternal-terminal
LABEL sh.demyx.maintainer   Demyx <info@demyx.sh>
LABEL sh.demyx.url          https://demyx.sh
LABEL sh.demyx.github       https://github.com/demyxco
LABEL sh.demyx.registry     https://hub.docker.com/u/demyx

ENV DEMYX                   /demyx
ENV DEMYX_CONFIG            /etc/demyx
ENV DEMYX_LOG               /var/log/demyx
ENV TZ                      America/Los_Angeles

# Packages
RUN set -ex; \
    apk add --update --no-cache \
        bash \
        libsodium \
        openssh \
        protobuf-dev \
        sudo \
        tzdata

# Configure Demyx
RUN set -ex; \
    # Create demyx user
    addgroup -g 1000 -S demyx; \
    adduser -u 1000 -D -S -G demyx demyx; \
    \
    # Create demyx directories
    install -d -m 0755 -o demyx -g demyx "$DEMYX"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_CONFIG"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_LOG"; \
    \
    # Update .bashrc
    echo 'PS1="$(whoami)@\h:\w \$ "' > /home/demyx/.bashrc; \
    echo 'PS1="$(whoami)@\h:\w \$ "' > /root/.bashrc

# EternalTerminal
RUN set -ex; \
    # Install deps
    apk add --no-cache --virtual .build-deps \
        boost-dev \
        build-base \
        cmake \
        git \
        gflags-dev \
        libexecinfo \
        libsodium-dev \
        libutempter-dev \
        m4 \
        perl \
        protobuf-dev; \
    \
    git clone --recurse-submodules https://github.com/MisterTea/EternalTerminal.git "$DEMYX_CONFIG"/EternalTerminal; \
    \
    # Patches to make it work for alpine
    sed -i 's/-DELPP_FEATURE_CRASH_LOG//g' "$DEMYX_CONFIG"/EternalTerminal/CMakeLists.txt; \
    sed -i '/UniversalStacktrace/d' "$DEMYX_CONFIG"/EternalTerminal/CMakeLists.txt; \
    sed -i '/#include "ust.hpp"/d' "$DEMYX_CONFIG"/EternalTerminal/src/base/Headers.hpp; \
    sed -i 's/<< "Stack Trace: " << endl << ust::generate()//g' "$DEMYX_CONFIG"/EternalTerminal/src/base/Headers.hpp; \
    sed -i 's/NULL))/(char *)0))/g' "$DEMYX_CONFIG"/EternalTerminal/src/terminal/PsuedoUserTerminal.hpp; \
    sed -i 's/--login", NULL/--login", (char *)0/g' "$DEMYX_CONFIG"/EternalTerminal/src/htm/TerminalHandler.cpp; \
    \
    # Build
    cd "$DEMYX_CONFIG"/EternalTerminal; \
    mkdir build; \
    cd build; \
    cmake ../; \
    make; \
    make install; \
    if [ ! -f /usr/local/bin/etserver ] ; then exit 1; fi; \
    \
    # Cleanups
    rm -rf "$DEMYX_CONFIG"/EternalTerminal; \
    apk del .build-deps; \
    rm -rf /var/cache/apk/*

# Configure sudo
RUN set -ex; \
    \
    /bin/echo "demyx ALL=(ALL) NOPASSWD:SETENV: /usr/local/bin/demyx-entrypoint" > /etc/sudoers.d/demyx; \
    # Suppress "sudo: setrlimit(RLIMIT_CORE): Operation not permitted"
    echo "Set disable_coredump false" >> /etc/sudo.conf

# Configure ssh
RUN set -ex; \
    # Configure user
    mkdir -p /home/demyx/.ssh; \
    echo demyx:demyx | chpasswd; \
    sed -i "s|/home/demyx:/sbin/nologin|/home/demyx:/bin/bash|g" /etc/passwd; \
    # Configure sshd_config
    sed -i "s|#PermitRootLogin prohibit-password|PermitRootLogin no|g" /etc/ssh/sshd_config; \
    sed -i "s|#PubkeyAuthentication yes|PubkeyAuthentication yes|g" /etc/ssh/sshd_config; \
    sed -i "s|#PasswordAuthentication yes|PasswordAuthentication no|g" /etc/ssh/sshd_config; \
    sed -i "s|#PermitEmptyPasswords no|PermitEmptyPasswords no|g" /etc/ssh/sshd_config

# Imports
COPY src/bin /usr/local/bin

EXPOSE 2022

USER demyx

ENTRYPOINT ["sudo", "-E", "demyx-entrypoint"]
