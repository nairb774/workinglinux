#!/usr/bin/env bash

cd "${0/*}"

docker rm workinglinux

docker run \
  --name workinglinux \
  --detach \
  --privileged \
  --publish 2222:22 \
  --mount type=tmpfs,destination=/tmp \
  --mount type=tmpfs,destination=/run \
  --mount type=tmpfs,destination=/run/lock \
  --mount type=bind,source=/,target=/mnt/host \
  --mount type=bind,source=/sys/fs/cgroup,target=/sys/fs/cgroup \
  --mount type=bind,source=/sys/fs/fuse,target=/sys/fs/fuse \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock.outer \
  -v "backup:/mnt/backup" \
  -v "docker:/var/lib/docker" \
  -v "homedir:/home/$USER" \
  -v "/opt/restic/backup/$USER:/opt/restic/backup/$USER" \
  -v "$HOME/workinglinux:/mnt/macos" \
  "$@" \
  nairb774/workinglinux

until nc 127.0.0.1 2222 < /dev/null | grep -q '^SSH-'; do
  sleep 0.1
done

exec ssh workinglinux
