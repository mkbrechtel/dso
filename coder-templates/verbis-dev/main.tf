terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.21.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.22"
    }
  }
}

locals {
#  username = data.coder_workspace.me.owner
  username = "coder"
  home = "/home/${local.username}"

  request_manager_url = "https://requests.dktk.dkfz.de"
  beam_broker = "broker.ccp-it.dktk.dkfz.de"
  beam_proxy_id = "central-ds-orchestrator.${local.beam_broker}"
  beam_proxy_url = "${local.request_manager_url}/beam/"
}

data "coder_provisioner" "me" {
}

provider "docker" {
}

data "coder_workspace" "me" {
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = "${data.coder_workspace.me.owner}"
    GIT_COMMITTER_NAME  = "${data.coder_workspace.me.owner}"
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner_email}"
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner_email}"
    DOTFILES_URI        = data.coder_parameter.dotfiles_uri.value != "" ? data.coder_parameter.dotfiles_uri.value : null
    START_VSCODE        = data.coder_parameter.start_vscode_server.value
    START_JUPYTER       = data.coder_parameter.start_jupyter.value
    START_RSTUDIO       = data.coder_parameter.start_rstudio.value
    START_BEAM          = data.coder_parameter.start_beam.value
  }
}

resource "coder_script" "startup-script" {
  run_on_start = true
  start_blocks_login = true
  timeout = 10

  agent_id = coder_agent.main.id
  display_name = "Startup script"
  script = <<-EOF
    set -e

    sudo dockerd &> /tmp/coder-docker.log &

    if [ "$START_VSCODE" == "1" ]; then
      code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
    fi

    if [ -n "$DOTFILES_URI" ]; then
      echo "Installing dotfiles from $DOTFILES_URI"
      coder dotfiles -y "$DOTFILES_URI"
    else
      echo "No dotfile_url supplied -- please supply in config."
    fi

    echo "Startup script finished."
  EOF
}

resource "coder_script" "beam-file-startup" {
  count        = data.coder_parameter.start_beam.value == "0" ? 0 : 1

  run_on_start = true
  start_blocks_login = true
  timeout = 10

  agent_id = coder_agent.main.id
  display_name = "Beam-File Receiver"
  script = <<-EOF
    set -e

    export BEAM_URL="${local.beam_proxy_url}"
    export BEAM_SECRET="${data.coder_parameter.beam_app_secret.value}"
    export BEAM_ID="${data.coder_parameter.beam_app_id_short.value}.${local.beam_proxy_id}"
    WORK_DIR=/ccp/incoming

    mkdir -p $WORK_DIR
    chown -R ${local.username}:${local.username} $WORK_DIR
    beam-file receive save --outdir=$WORK_DIR >/tmp/beam-file.log 2>&1 &

    echo "Started Beam.File receiver."
  EOF
}

resource "coder_script" "beam-connect-startup" {
  count        = data.coder_parameter.start_beam.value == "0" ? 0 : 1

  run_on_start = true
  start_blocks_login = true
  timeout = 10

  agent_id = coder_agent.main.id
  display_name = "Beam-Connect Proxy"
  script = <<-EOF
    set -e
    echo "Starting Beam.Connect"

    CONFIG_DIR=/etc/beam-connect
    export PROXY_URL="${local.beam_proxy_url}"
    export PROXY_APIKEY="${data.coder_parameter.beam_app_secret.value}"
    export APP_ID="${data.coder_parameter.beam_app_id_short.value}.${local.beam_proxy_id}"
    export DISCOVERY_URL="$CONFIG_DIR/central.json"
    export LOCAL_TARGETS_FILE="$CONFIG_DIR/local.json"
    export NO_AUTH="true"

    sudo mkdir -p $CONFIG_DIR
    sudo chown -R ${local.username}:${local.username} $CONFIG_DIR
    echo "[]" >> $CONFIG_DIR/local.json
    curl -ksf ${local.request_manager_url}/datashield-sites | jq -n --args '{"sites": input | map({
        "name": .,
        "id": .,
        "virtualhost": "\(.):443",
        "beamconnect": "datashield-connect.\(.).${local.beam_broker}"
    })}' > $CONFIG_DIR/central.json
    beam-connect > /tmp/beam-connect.log 2>&1 &

    echo "Started Beam.Connect"
  EOF
}

resource "coder_script" "jupyter-startup" {
  count        = data.coder_parameter.start_jupyter.value == "0" ? 0 : 1

  run_on_start = true
  start_blocks_login = true
  timeout = 10

  agent_id = coder_agent.main.id
  display_name = "Start Jupyter Lab"
  script = <<-EOF
    set -e

    jupyter lab \
      --ServerApp.base_url=/@${data.coder_workspace.me.owner}/${data.coder_workspace.me.name}/apps/jupyter/ \
      --ServerApp.token='' --ip='*' >/tmp/jupyter.log 2>&1 &

    echo "Jupyter Lab started up."
  EOF
}

resource "coder_script" "rstudio-startup" {
  count        = data.coder_parameter.start_rstudio.value == "0" ? 0 : 1

  run_on_start = true
  start_blocks_login = true
  timeout = 10

  agent_id = coder_agent.main.id
  display_name = "Start RStudio"
  script = <<-EOF
    set -e

    /usr/lib/rstudio-server/bin/rserver --server-daemonize=1 --auth-none=1 >/tmp/rstudio.log 2>&1 &

    echo "RStudio starting up."
  EOF
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  count        = data.coder_parameter.start_vscode_server.value == "0" ? 0 : 1

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
 }
}

resource "coder_app" "jupyter" {
  agent_id     = coder_agent.main.id
  slug         = "jupyter"
  display_name = "Jupyter Lab"
  url          = "http://localhost:8888/@${data.coder_workspace.me.owner}/${data.coder_workspace.me.name}/apps/jupyter"
  icon         = "/icon/jupyter.svg"
#  subdomain    = false
#  share        = "owner"
  count        = data.coder_parameter.start_jupyter.value == "0" ? 0 : 1

#  healthcheck {
#    url       = "http://localhost:8888/healthz"
#    interval  = 5
#    threshold = 6
# }
}

resource "coder_app" "rstudio" {
  count        = data.coder_parameter.start_rstudio.value == "0" ? 0 : 1

  agent_id     = coder_agent.main.id
  slug         = "rstudio"
  display_name = "RStudio Server"
  url          = "http://localhost:8787"
  icon         = "/icon/rstudio.svg"
  subdomain    = true
#  share        = "owner"

  healthcheck {
    url       = "http://localhost:8787/healthz"
    interval  = 3
    threshold = 10
 }
}

resource "docker_volume" "cache_volume" {
  name = "coder-${data.coder_workspace.me.owner}-cache"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

/*resource "docker_image" "self-built" {
  name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.id}"
  keep_locally = true
  build {
     context = "./build"
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}*/

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
#  image = docker_image.self-built.name
  image = "docker.verbis.dkfz.de/verbis/verbis-dev-base:latest"
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/mnt/cache"
    volume_name    = docker_volume.cache_volume.name
    read_only      = false
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
  runtime = "sysbox-runc"
  shm_size = 4096
#  tmpfs = {
#    "/tmp" : ""
#  }
#  tmpfs = {
#    "{local.home}/.cargo": ""
#  }
}

data "coder_parameter" "dotfiles_uri" {
  name = "Your Dotfiles URL"
  description = <<-EOF
  Your home directory is not persisted.
  Instead, please supply a dotfile repo URI, e.g. git@github.com:YOURNAME/dotfiles.git.
  See https://coder.com/docs/v2/latest/dotfiles
  EOF
  default = ""
  type = "string"
  mutable = true
}

data "coder_parameter" "start_vscode_server" {
  name = "Enable VS Code Server?"
  description = "Would you like to use VS Code Server within your web browser? This is not required for use with your Desktop VS Code."
  type = "string"
  option {
    name = "No (I can change this later here)"
    value = "0"
  }
  option {
    name = "Yes, please start automatically"
    value = "1"
  }
  mutable = true
}

data "coder_parameter" "start_jupyter" {
  name = "Enable Jupyter Lab?"
  description = "Would you like to use Jupyter Lab within your web browser?"
  type = "string"
  option {
    name = "No (I can change this later here)"
    value = "0"
  }
  option {
    name = "Yes, please start automatically"
    value = "1"
  }
  mutable = true
}

data "coder_parameter" "start_rstudio" {
  name = "Enable RStudio?"
  description = "Would you like to use RStudio within your web browser?"
  type = "string"
  option {
    name = "No (I can change this later here)"
    value = "0"
  }
  option {
    name = "Yes, please start automatically"
    value = "1"
  }
  mutable = true
}

data "coder_parameter" "start_beam" {
  name = "Samply.Beam: Enable file receiver"
  description = "Would you like to enable file ingress via Samply.Beam?"
  type = "string"
  option {
    name = "No (I can change this later here)"
    value = "0"
  }
  option {
    name = "Yes, please start automatically"
    value = "1"
  }
  mutable = true
  default = "0"
  order = 10
}

data "coder_parameter" "beam_app_id_short" {
  name = "Samply.Beam: App ID (short)"
  type = "string"
  mutable = true
  default = ""
  order = 11
}

data "coder_parameter" "beam_app_secret" {
  name = "Samply.Beam: App Secret"
  type = "string"
  mutable = true
  default = ""
  order = 12
}
