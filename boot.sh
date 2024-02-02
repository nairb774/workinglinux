#!/usr/bin/env bash

cd "${0/*}"

gpg --card-status

limactl shell workinglinux sudo nerdctl rm workinglinux

limactl shell workinglinux sudo nerdctl run \
  --name workinglinux \
  --detach \
  --privileged \
  --cgroupns=host \
  --publish 2222:22 \
  --mount type=tmpfs,destination=/tmp \
  --mount type=tmpfs,destination=/run \
  --mount type=tmpfs,destination=/run/lock \
  --mount type=bind,source=/,target=/mnt/host \
  -v "backup:/mnt/backup" \
  -v "docker:/var/lib/docker" \
  -v "homedir:/home/$USER" \
  -v "$HOME/workinglinux:/mnt/macos" \
  "$@" \
  nairb774/workinglinux

until nc 127.0.0.1 2222 < /dev/null | grep -q '^SSH-'; do
  sleep 0.1
done

exec ssh workinglinux
