# syntax=docker/dockerfile:1.4@sha256:9ba7531bd80fb0a858632727cf7a112fbfd19b17e94c4e84ced81e24ef1a0dbc

# The archlinux/archlinux repo is updated daily:
FROM archlinux/archlinux:base-devel@sha256:451510a216a07bbf968d92bda04f894e86aaa60653a6a9ee00043aa471c98538 AS base

COPY --chown=root:root /mirrorlist /etc/pacman.d/mirrorlist

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
    unzip \
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
  useradd -u 1100 -m -G wheel aur; \
  echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-wheel-nopw; \
  echo 'PKGDEST=/home/aur/packages' >> /etc/makepkg.conf; \
  echo 'SRCDEST=/home/aur/src' >> /etc/makepkg.conf; \
  touch -t 197001010000 /next; \
  echo Done
USER aur
RUN set -eux; \
  mkdir -p /home/aur/packages /home/aur/src /home/aur/work; \
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
  echo Done
WORKDIR /home/aur/work

FROM aur AS aur_1password-cli
COPY --chown=1100:1100 /aur/1password-cli /home/aur/work
RUN makepkg -cCs --noconfirm

FROM aur AS aur_amazon-ecr-credential-helper
COPY --chown=1100:1100 /aur/amazon-ecr-credential-helper /home/aur/work
COPY --from=aur_1password-cli /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_aws-cli-v2-bin
COPY --chown=1100:1100 /aur/aws-cli-v2-bin /home/aur/work
COPY --from=aur_amazon-ecr-credential-helper /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_bazelisk
COPY --chown=1100:1100 /aur/bazelisk /home/aur/work
COPY --from=aur_aws-cli-v2-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_carvel-tools
COPY --chown=1100:1100 /aur/carvel-tools /home/aur/work
COPY --from=aur_bazelisk /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_circleci-cli-bin
COPY --chown=1100:1100 /aur/circleci-cli-bin /home/aur/work
COPY --from=aur_carvel-tools /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_conftest
COPY --chown=1100:1100 /aur/conftest /home/aur/work
COPY --from=aur_circleci-cli-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_dive
COPY --chown=1100:1100 /aur/dive /home/aur/work
COPY --from=aur_conftest /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_dyff-bin
COPY --chown=1100:1100 /aur/dyff-bin /home/aur/work
COPY --from=aur_dive /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_flux-bin
COPY --chown=1100:1100 /aur/flux-bin /home/aur/work
COPY --from=aur_dyff-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_fswatch
COPY --chown=1100:1100 /aur/fswatch /home/aur/work
COPY --from=aur_flux-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_go-crane-bin
COPY --chown=1100:1100 /aur/go-crane-bin /home/aur/work
COPY --from=aur_fswatch /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_google-cloud-sdk
COPY --chown=1100:1100 /aur/google-cloud-sdk /home/aur/work
COPY --from=aur_go-crane-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_grpcui
COPY --chown=1100:1100 /aur/grpcui /home/aur/work
COPY --from=aur_google-cloud-sdk /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_istio-bin
COPY --chown=1100:1100 /aur/istio-bin /home/aur/work
COPY --from=aur_grpcui /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_kind-bin
COPY --chown=1100:1100 /aur/kind-bin /home/aur/work
COPY --from=aur_istio-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_mongodb-shell
COPY --chown=1100:1100 /aur/mongodb-shell /home/aur/work
COPY --from=aur_kind-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_nvm
COPY --chown=1100:1100 /aur/nvm /home/aur/work
COPY --from=aur_mongodb-shell /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_ookla-speedtest-bin
COPY --chown=1100:1100 /aur/ookla-speedtest-bin /home/aur/work
COPY --from=aur_nvm /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_opa
COPY --chown=1100:1100 /aur/opa /home/aur/work
COPY --from=aur_ookla-speedtest-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_protoc-gen-go
COPY --chown=1100:1100 /aur/protoc-gen-go /home/aur/work
COPY --from=aur_opa /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_rdfind
COPY --chown=1100:1100 /aur/rdfind /home/aur/work
COPY --from=aur_protoc-gen-go /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_reviewdog-bin
COPY --chown=1100:1100 /aur/reviewdog-bin /home/aur/work
COPY --from=aur_rdfind /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_symlinks
COPY --chown=1100:1100 /aur/symlinks /home/aur/work
COPY --from=aur_reviewdog-bin /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_terraform-docs-bin
COPY --chown=1100:1100 /aur/terraform-docs-bin /home/aur/work
COPY --from=aur_symlinks /next /next
RUN makepkg -cCs --noconfirm

FROM aur AS aur_tfenv
COPY --chown=1100:1100 /aur/tfenv /home/aur/work
COPY --from=aur_terraform-docs-bin /next /next
RUN makepkg -cCs --noconfirm

FROM scratch AS aur-packages
COPY --from=aur_1password-cli --link /home/aur/packages/* /packages/
COPY --from=aur_amazon-ecr-credential-helper --link /home/aur/packages/* /packages/
COPY --from=aur_aws-cli-v2-bin --link /home/aur/packages/* /packages/
COPY --from=aur_bazelisk --link /home/aur/packages/* /packages/
COPY --from=aur_carvel-tools --link /home/aur/packages/* /packages/
COPY --from=aur_circleci-cli-bin --link /home/aur/packages/* /packages/
COPY --from=aur_conftest --link /home/aur/packages/* /packages/
COPY --from=aur_dive --link /home/aur/packages/* /packages/
COPY --from=aur_dyff-bin --link /home/aur/packages/* /packages/
COPY --from=aur_flux-bin --link /home/aur/packages/* /packages/
COPY --from=aur_fswatch --link /home/aur/packages/* /packages/
COPY --from=aur_go-crane-bin --link /home/aur/packages/* /packages/
COPY --from=aur_google-cloud-sdk --link /home/aur/packages/* /packages/
COPY --from=aur_grpcui --link /home/aur/packages/* /packages/
COPY --from=aur_istio-bin --link /home/aur/packages/* /packages/
COPY --from=aur_kind-bin --link /home/aur/packages/* /packages/
COPY --from=aur_mongodb-shell --link /home/aur/packages/* /packages/
COPY --from=aur_nvm --link /home/aur/packages/* /packages/
COPY --from=aur_ookla-speedtest-bin --link /home/aur/packages/* /packages/
COPY --from=aur_opa --link /home/aur/packages/* /packages/
COPY --from=aur_protoc-gen-go --link /home/aur/packages/* /packages/
COPY --from=aur_rdfind --link /home/aur/packages/* /packages/
COPY --from=aur_reviewdog-bin --link /home/aur/packages/* /packages/
COPY --from=aur_symlinks --link /home/aur/packages/* /packages/
COPY --from=aur_terraform-docs-bin --link /home/aur/packages/* /packages/
COPY --from=aur_tfenv --link /home/aur/packages/* /packages/

FROM base AS layer-img

ARG USER

RUN --mount=type=bind,from=aur-packages,source=/packages,target=/tmp/bind/aur/packages \
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
  tfenv install 1.5.4; \
  [ ! -e /tmp/bind/extensions/post_install.sh ] || /tmp/bind/extensions/post_install.sh; \
  echo Done

# Configure system:
COPY --chown=root:root /docker-host.socket /docker-host.service /usr/local/lib/systemd/system/
COPY --chown=root:docker /docker-daemon.json /etc/docker/daemon.json
COPY --chown=root:root /gpg-agent-dir.service /etc/systemd/user/gpg-agent-dir.service
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
COPY --chown=$USER:$USER /generated/authorized_keys /home/$USER/.ssh/authorized_keys
COPY --chown=$USER:$USER /generated/gpg-public-keys.asc /home/$USER/gpg-public-keys.asc
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
