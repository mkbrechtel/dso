#!/bin/bash -e

verbis_install_vscode_extensions() {
  mkdir -p /home/coder/.vscode-server
  while [ -n "$1" ]; do
    code-server --install-extension $1 --extensions-dir /home/coder/.vscode-server/extensions
    shift
  done
}
export -f verbis_install_vscode_extensions


verbis_symlink_cache_dir() {
  if [ -e ~/$1 ] && [ ! -L ~/$1 ]; then
    echo "Removing existing non-symlink: ~/$1"
    rm -r ~/$1
  fi
  mkdir -p /mnt/cache/$1 ~/$(dirname $1)
  ln -sf /mnt/cache/$1 ~/$(dirname $1)
}
export -f verbis_symlink_cache_dir


verbis_symlink_cache_file() {
  if [ -e ~/$1 ] && [ ! -L ~/$1 ]; then
    echo "Removing existing non-symlink: ~/$1"
    rm -r ~/$1
  fi
  ln -sf /mnt/cache/$1 ~/$(dirname $1)
}
export -f verbis_symlink_cache_file


# e.g. verbis_clone github.com:samply/beam
verbis_clone() {
  REPO=$1
  BRANCH=$2

  DIR=~/git/$(basename -s '.git' $REPO)
  OPTS=""
  if [ -n "$BRANCH" ]; then
    OPTS+="-b $BRANCH"
  fi
  if [[ $REPO =~ ^https://github.com/ ]]; then
    REPO=$(echo $REPO | sed 's_https://github.com/_git@github.com:_')
  fi
  if [[ $REPO =~ \.git$ ]]; then
    REPO=$(echo $REPO | sed -e 's_\.git$__')
  fi
  if [ ! -x $DIR ]; then
    git clone $OPTS $REPO.git $DIR
  fi
}
export -f verbis_clone

verbis_defaults_rust() {
  verbis_symlink_cache_dir .cargo/registry
# The following is already done as part of the image
#  verbis_install_vscode_extensions rust-lang.rust-analyzer vadimcn.vscode-lldb serayuzgur.crates
}
export -f verbis_defaults_rust

verbis_defaults_java() {
  verbis_symlink_cache_dir .m2
}
export -f verbis_defaults_java

verbis_defaults_main() {
  verbis_symlink_cache_file .bash_history
  verbis_symlink_cache_dir .ssh
  if [ ! -e ~/.ssh/known_hosts ]; then
    ssh-keyscan github.com >> ~/.ssh/known_hosts
  fi
}
export -f verbis_defaults_main
