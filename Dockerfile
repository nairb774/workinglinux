# syntax=docker/dockerfile:1.4@sha256:f2e1edebd1f6deb247a04673878e6883f3c5f28d7cc9ae05abbb9b6ab67a09b8

# The archlinux/archlinux repo is updated daily:
FROM archlinux/archlinux:base-devel@sha256:1936e55e5a495c74b887cb1905d7746b1ee81cdbfc14aa6b671448b5bd9282b2 AS base

COPY --link --chown=root:root /mirrorlist /etc/pacman.d/mirrorlist

RUN set -eux; \
  sed -i -e '\|NoExtract  = usr/share/man/\* usr/share/info/\*|d' /etc/pacman.conf; \
  grep -vq usr/share/man /etc/pacman.conf; \
  pacman -Suy --noconfirm; \
  # Install all the tools we need pre-configured:
  pacman -S --noconfirm \
    # To force manpages to be added:
    bash \
    bash-completion \
    bind \
    byobu \
    cmake \
    docker \
    docker-buildx \
    docker-compose \
    ed \
    entr \
    flatbuffers \
    git \
    github-cli \
    gnu-netcat \
    go \
    go-yq \
    graphviz \
    grpc-cli \
    jq \
    k9s \
    ko \
    kubectl \
    kubeseal \
    kustomize \
    lsof \
    man-db \
    man-pages \
    neovim \
    nmap \
    nodejs \
    npm \
    openssh \
    packer \
    pacman-contrib \
    pigz \
    poetry \
    postgresql-libs \
    protobuf \
    pyenv \
    python-pipenv \
    qrencode \
    rclone \
    restic \
    rsync \
    shellcheck \
    skopeo \
    socat \
    stow \
    # For xxd:
    vim \
    wget \
    whois \
    xorg-xauth \
    yapf \
  ; \
  echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen; \
  locale-gen; \
  echo Done

FROM base AS aur
RUN set -eux; \
  useradd -m -G wheel aur; \
  echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-wheel-nopw; \
  echo 'PKGDEST=/home/aur/packages' >> /etc/makepkg.conf; \
  echo 'SRCDEST=/home/aur/src' >> /etc/makepkg.conf; \
  mkdir -p /home/aur/packages /home/aur/src /home/aur/work; \
  chown -R aur:aur /home/aur/*; \
  echo Done
USER aur
WORKDIR /home/aur/work

RUN --mount=type=bind,source=/aur,target=/home/aur/work,rw \
  set -eux; \
  gpg --keyserver hkps://keyserver.ubuntu.com --receive-keys \
    # Keys used to sign 1password-cli:
    # pub   rsa4096 2017-05-18 [SC] [expires: 2025-05-16]
    #       3FEF9748469ADBE15DA7CA80AC2D62742012EA22
    # uid           [ unknown] Code signing for 1Password <codesign@1password.com>
    3FEF9748469ADBE15DA7CA80AC2D62742012EA22 \
    # Key used to sign rdfind:
    # pub   rsa4096 2020-08-04 [SC] [expires: 2025-08-03]
    #       CC3C51BA88205B19728A6F07C9D9A0EA44EAE0EB
    # uid           [ unknown] Paul Dreik (private key) <paul@pauldreik.se>
    # uid           [ unknown] Rdfind <rdfind@pauldreik.se>
    # sub   rsa4096 2020-08-04 [E] [expires: 2025-08-03]
    CC3C51BA88205B19728A6F07C9D9A0EA44EAE0EB \
  ; \
  sudo chown -R aur:aur /home/aur/work; \
  for PKG in *; do ( \
    cd "$PKG"; \
    makepkg -cCs --noconfirm; \
  ); done; \
  echo Done

FROM base AS layer-img

ARG USER

RUN --mount=type=bind,from=aur,source=/home/aur/packages,target=/tmp/bind/aur/packages \
    --mount=type=bind,source=/extensions,target=/tmp/bind/extensions \
  set -eux; \
  # This is needed to prevent the system from trying to configure on boot:
  systemd-firstboot \
    --hostname workinglinux \
    --keymap us \
    --locale en_US.UTF-8 \
    --timezone America/Los_Angeles \
  ; \
  useradd -m -G wheel $USER; \
  pacman -U --noconfirm /tmp/bind/aur/packages/*; \
  tfenv install 1.0.11; \
  [ ! -e /tmp/bind/extensions/post_install.sh ] || /tmp/bind/extensions/post_install.sh; \
  echo Done

# Configure system:
COPY --link --chown=root:root /docker-host.socket /docker-host.service /usr/local/lib/systemd/system/
COPY --link --chown=root:docker /docker-daemon.json /etc/docker/daemon.json
COPY --link --chown=root:root /gpg-agent-dir.service /etc/systemd/user/gpg-agent-dir.service
RUN set -eux; \
  # Disable services that don't make sense in a container. See:
  # https://github.com/nestybox/sysbox/blob/4c1ed53119823adf76fcac67fa5ac74344dc79ca/docs/user-guide/systemd.md
  systemctl mask \
    systemd-firstboot.service \
    systemd-journald-audit.socket \
    systemd-networkd-wait-online.service \
    systemd-udev-trigger.service \
  ; \
  # Switch to multi-user as the default (not graphical). See:
  # https://github.com/nestybox/dockerfiles/blob/d87306e01a9ff525e2a5a7645278ab56568e2923/archlinux-systemd/Dockerfile
  systemctl set-default multi-user.target; \
  # Enable some base services:
  systemctl enable docker.socket; \
  systemctl enable docker-host.socket; \
  systemctl enable sshd.service; \
  # Make sure that the /var/run/user/$UID/gnupg dir exists unconditionally.
  systemctl enable --global gpg-agent-dir.service; \
  echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-wheel-nopw; \
  # Allow the `user` user to be able to forward unix domain sockets on top of
  # existing sockets.
  echo 'Match User '$USER >> /etc/ssh/sshd_config; \
  echo '  StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config; \
  # Enable X11 forwarding support as well:
  echo '  X11Forwarding yes' >> /etc/ssh/sshd_config; \
  # Also needed for X11 forwarding, but can't be in a match statement:
  sed -i -e 's|#AddressFamily any|AddressFamily inet|' /etc/ssh/sshd_config; \
  echo Done

# Configure user:
COPY --link --chown=$USER:$USER /generated/authorized_keys /home/$USER/.ssh/authorized_keys
COPY --link --chown=$USER:$USER /generated/gpg-public-keys.asc /home/$USER/gpg-public-keys.asc
RUN set -eux; \
  usermod -a -G docker $USER; \
  usermod -a -G tfenv $USER; \
  cat /etc/passwd; \
  find /home -type f; \
  chown -R $USER:$USER /home/$USER/.ssh; \
  chmod 700 /home/$USER/.ssh; \
  chmod 600 /home/$USER/.ssh/*; \
  sudo -u $USER gpg --import /home/$USER/gpg-public-keys.asc; \
  rm /home/$USER/gpg-public-keys.asc; \
  echo Done

# Prune a bunch of files:
RUN set -eux; \
  # Remove all cache files:
  paccache -rk0; \
  rm -rf /tmp/bind; \
  echo Done

FROM scratch AS img

# We make a single layer image with all the files:
COPY --link --from=layer-img / /
ENV container=docker
ENTRYPOINT ["/usr/lib/systemd/systemd"]
CMD ["--log-level=info", "--unit=multi-user.target"]
