#!/bin/sh
export PATH=/home/server/local/bin:$PATH
while true; do
  if nc -z localhost 8888; then
    exit 0
  fi
  git checkout .
  git pull
  npm install
  API_PORT=8888 xinit `which npm` start -- :8 >> keeprunning.log 2>&1
done
