# The archlinux/archlinux repo is updated daily:
FROM archlinux/archlinux:base-devel@sha256:117d5723d14994fc168fc422d39ae2bc83b133267381d9b002af84b3e2eb609d AS base

COPY --chown=root:root /mirrorlist /etc/pacman.d/mirrorlist

# WORKAROUND for glibc 2.33 and old Docker
# See https://github.com/actions/virtual-environments/issues/2658
# Thanks to https://github.com/lxqt/lxqt-panel/pull/1562
# https://github.com/qutebrowser/qutebrowser/commit/478e4de7bd1f26bebdcdc166d5369b2b5142c3e2
#
# Keep an eye on https://bugs.archlinux.org/task/69563 for current state.
RUN set -eux; \
  PATCHED_GLIBC=glibc-linux4-2.33-4-x86_64.pkg.tar.zst; \
  # TODO: Quite sus cn???
  curl -LO "https://repo.archlinuxcn.org/x86_64/$PATCHED_GLIBC"; \
  sha256sum -c <<< "a89f4d23ae7cde78b4258deec4fcda975ab53c8cda8b5e0a0735255c0cdc05cc  $PATCHED_GLIBC"; \
  tar -C / -xvf "$PATCHED_GLIBC"; \
  rm "$PATCHED_GLIBC"; \
  echo Done

RUN set -eux; \
  sed -i -e '\|NoExtract  = usr/share/man/\* usr/share/info/\*|d' /etc/pacman.conf; \
  grep -vq usr/share/man /etc/pacman.conf; \
  pacman -Sy; \
  pacman -S --noconfirm \
    # Force upgrade everything (needed becuase of pacman.conf changes). Until
    # the prior glibc patch is fixed, skip glibc:
    $(pacman -Qnq | grep -v ^glibc) \
  ; \
  # Once glibc problem is gone...
  # pacman -Suy --noconfirm; \
  echo Done

FROM base AS aur
RUN set -eux; \
  useradd -m -G wheel aur; \
  echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-wheel-nopw; \
  echo 'PKGDEST=/home/aur/packages' >> /etc/makepkg.conf; \
  echo 'SRCDEST=/home/aur/src' >> /etc/makepkg.conf; \
  pacman -S --noconfirm git; \
  mkdir -p /home/aur/packages /home/aur/src /home/aur/work; \
  chown -R aur:aur /home/aur/*; \
  echo Done
USER aur
WORKDIR /home/aur/work

COPY --chown=aur:aur /aur .
RUN set -eux; \
  # Keys used to sign 1password-cli:
  gpg --receive-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22; \
  # To prevent the GOFLAGS from carrying through:
  sudo pacman -S --noconfirm go; \
  echo 'TODO: ko'; \
  for PKG in \
    1password-cli \
    amazon-ecr-credential-helper \
    aws-cli-v2-bin \
    carvel-tools \
    conftest \
    dive \
    flux-bin \
    fswatch \
    grpcui \
    istio-bin \
    kind-bin \
    nvm \
    opa \
    protoc-gen-go \
    terraform-docs-bin \
    tfenv \
  ; do ( \
    [ -e "$PKG" ] || git clone "https://aur.archlinux.org/$PKG.git" "$PKG"; \
    cd "$PKG"; \
    GOFLAGS=-mod=mod makepkg -cCs --noconfirm; \
  ); done; \
  echo Done

FROM base AS layer-img

ARG USER

RUN set -eux; \
  # This is needed to prevent the system from trying to configure on boot:
  ln -srf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime; \
  # We seem to need this for journalctl to be able to start:
  # systemd-machine-id-setup; \
  useradd -m -G wheel $USER; \
  echo Done

COPY --chown=root:root --from=aur /home/aur/packages/* /aur/packages/
COPY --chown=root:root /extensions /tmp/extensions

RUN set -eux; \
  # AUR packages - using file:// format to force copy into cache:
  # pacman -U --noconfirm $(find /aur/packages -type f -printf 'file://%p\n'); \
  pacman -U --noconfirm /aur/packages/*; \
  # Remove imported aur files:
  rm -rf /aur; \
  # Install all the tools we need pre-configured:
  pacman -S --noconfirm \
    bash-completion \
    bind \
    byobu \
    cmake \
    docker \
    docker-compose \
    entr \
    git \
    go \
    graphviz \
    grpc-cli \
    jq \
    k9s \
    kubectl \
    kubeseal \
    kustomize \
    lsof \
    man-db \
    man-pages \
    neovim \
    nodejs \
    npm \
    openssh \
    packer \
    pacman-contrib \
    pigz \
    protobuf \
    postgresql-libs \
    pyenv \
    python-pipenv \
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
    yapf \
    yq \
  ; \
  echo 'TODO: yq is a really different version...'; \
  tfenv install 0.13.5; \
  [ ! -e /tmp/extensions/post_install.sh ] || /tmp/extensions/post_install.sh; \
  echo Done

# Configure system:
COPY --chown=root:root /docker-proxy.conf /etc/systemd/system/docker.service.d/docker-proxy.conf
COPY --chown=root:root /gpg-agent-dir.service /etc/systemd/user/gpg-agent-dir.service
RUN set -eux; \
  systemctl enable docker.service; \
  systemctl enable docker.socket; \
  systemctl enable sshd.service; \
  # Make sure that the /var/run/user/$UID/gnupg dir exists unconditionally.
  systemctl enable --global gpg-agent-dir.service; \
  echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/90-wheel-nopw; \
  # Allow the `user` user to be able to forward unix domain sockets on top of
  # existing sockets.
  echo 'Match User '$USER >> /etc/ssh/sshd_config; \
  echo '  StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config; \
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
  rm -rf /tmp/extensions; \
  # Remove all cache files:
  paccache -rk0; \
  echo Done

FROM scratch AS img

# We make a single layer image with all the files:
COPY --from=layer-img / /
ENV container=docker
ENTRYPOINT ["/usr/lib/systemd/systemd"]
CMD ["--log-level=info", "--unit=multi-user.target"]
