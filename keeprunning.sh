#!/bin/sh
while true; do
  if nc -z localhost 8888; then
    exit 0
  fi
  npm install
  API_PORT=8888 xinit `which npm` start -- :8
done
