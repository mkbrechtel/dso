#!/bin/sh

exec podman run -it -v .:/app -v ../docs:/docs --workdir /app -p 4321:4321 --name dso-website --hostname dso-website node:20 sh -c  'yarn dev --host & exec bash'
