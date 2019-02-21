#!/bin/bash

# Note: pwgen doesn't exist for all platforms

command -v pwgen > /dev/null
if [ ! $? -eq 0 ]; then
  echo "Command pwgen is not installed on this platform"
  exit 1
fi

num_users=10
if [ ! -z "$1" ]; then
  num_users=$1
fi

for i in $(seq -f "%02g" 1 ${num_users}); do
  user="user${i}"
  pw=$(pwgen -y -n -c -s -N 1 12)
  echo "${user}|${pw}"
done
