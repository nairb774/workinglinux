#!/usr/bin/env bash

set -eux

cd "${0%/*}"

rm -rf context/generated
mkdir context/generated

ssh-add -L \
  | grep cardno \
  > context/generated/authorized_keys

gpg --export --armor > context/generated/gpg-public-keys.asc

exec docker buildx build \
  --progress=plain \
  --build-arg=USER="$USER" \
  --file "$PWD/Dockerfile" \
  --tag nairb774/workinglinux \
  --target img \
  "$PWD/context"
