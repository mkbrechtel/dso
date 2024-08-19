#!/bin/sh -e

docker rm -f dso-website
exec docker run -it -v .:/app -v ../docs:/docs --workdir /app -p 4321:4321 --name dso-website --hostname dso-website node:20 sh -c  'yarn install & yarn dev --host & exec bash'
