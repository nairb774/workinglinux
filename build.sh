#!/usr/bin/env bash

set -eux

cd "${0%/*}"

rm -rf context/generated
mkdir context/generated

ssh-add -L \
  | grep cardno \
  > context/generated/authorized_keys

gpg --export --armor > context/generated/gpg-public-keys.asc

COMMIT="$(git rev-parse HEAD)"

limactl shell workinglinux sudo nerdctl build \
  --progress=plain \
  --build-arg=USER="$USER" \
  --label git-commit="$COMMIT" \
  --file "$PWD/Dockerfile" \
  --tag "nairb774/workinglinux:$COMMIT" \
  --target img \
  "$PWD/context"

limactl shell workinglinux sudo nerdctl image tag "nairb774/workinglinux:$COMMIT" "nairb774/workinglinux:latest"
