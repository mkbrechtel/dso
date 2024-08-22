---
name: VerbIS Dev Image
description: We try to provide one image with all tools and sane defaults for all VerbIS-related activities.
tags: [local, docker, rust]
icon: /emojis/1f600.png
---

# VerbIS dev image

This is the default Coder docker image with the following changes:

- Installed Rust (per-user) plus libraries required by our software
- Installed npm, @angular/cli, prettier
- Always use newest code-server
- Don't persist home directy. Instead, use Dotfiles.
- docker, docker-compose, docker compose

## How to store data

Your home directory is not persisted. Please use a dotfiles repo and supply its URL upon
creating the workspace. For more info, see https://coder.com/docs/v2/latest/dotfiles.
