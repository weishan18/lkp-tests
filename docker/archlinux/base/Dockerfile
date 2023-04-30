FROM archlinux:base

# lkp install generates hosts/$HOSTNAME during create_host_config. Here it requires
# user to pass hostname arg to specify a consistent name instead of the container
# hostname when building the image.
ARG hostname=lkp-docker
ENV HOSTNAME=${hostname}

# use lkp user for yay installation
ARG user=lkp

RUN pacman -Syu --noconfirm && \
    pacman -Sy --noconfirm \
    # linux-tools installs turbostat and perf
    linux-tools \
    make \
    # for hostname command
    inetutils \
    # procps installs vmstat, sysctl, etc to partially persistent commonly used dependencies
    procps \
    sudo \
    # git and base-devel needed to clone yay and run makepkg for installation
    git \
    base-devel && \
    # create sudo user $user, add to sudoers (makepkg and yay can't run as root)
    useradd -m $user && \
    echo "$user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$user && \
    # enable preservation of proxy env variables under sudo (for yay to pull packages under proxy)
    echo "Defaults env_keep += \"ftp_proxy http_proxy https_proxy no_proxy\"" >> /etc/sudoers.d/$user

USER $user

WORKDIR /home/$user

# install yay, can't do it as root
RUN git clone https://aur.archlinux.org/yay.git && \
    cd yay && \
    makepkg -sri --needed --noconfirm && \
    cd && \
    # Clean up
    rm -rf .cache yay

USER root

WORKDIR /lkp/lkp-tests

COPY . ./

RUN make install && \
    lkp install

# add gem/bin into PATH and update, needed to install gem executables
RUN echo "PATH=\$PATH:$(ruby -e 'puts Gem.user_dir')/bin" >> /etc/profile.d/rubygempath.sh && \
    source /etc/profile.d/rubygempath.sh && \
    gem list && \
    gem update

ENTRYPOINT ["bash", "-c", "sleep infinity"]
