#!/usr/bin/env bash

set -eux

cd "${0%/*}"

rm -rf context/generated
mkdir context/generated

ssh-add -L \
  | grep cardno \
  > context/generated/authorized_keys

gpg --export --armor > context/generated/gpg-public-keys.asc

exec limactl shell workinglinux sudo nerdctl build \
  --progress=plain \
  --build-arg=USER="$USER" \
  --label git-commit="$(git rev-parse HEAD)" \
  --file "$PWD/Dockerfile" \
  --tag nairb774/workinglinux \
  --target img \
  "$PWD/context"
