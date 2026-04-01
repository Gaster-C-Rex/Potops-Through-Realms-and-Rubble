#!/bin/sh
printf '\033c\033]0;%s\a' Pottery DonJon
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Potops.x86_64" "$@"
