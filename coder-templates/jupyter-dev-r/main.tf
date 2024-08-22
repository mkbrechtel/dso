terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
    }
    docker = {
      source  = "kreuzwerker/docker"
    }
  }
}

variable "socket" {
  type        = string
  description = <<-EOF
  The Unix socket that the Docker daemon listens on and how containers
  communicate with the Docker daemon.

  Either Unix or TCP
  e.g., unix:///var/run/docker.sock

  EOF
  default = "unix:///var/run/docker.sock"
}

provider "docker" {
  host = var.socket
}

data "coder_workspace" "me" {
}

provider "coder" {

}

data "coder_parameter" "dotfiles_url" {
  name        = "Dotfiles URL"
  description = "Personalize your workspace"
  type        = "string"
#  default     = "git@github.com:sharkymark/dotfiles.git"
  mutable     = true 
  default     = ""
  icon        = "https://git-scm.com/images/logos/downloads/Git-Icon-1788C.png"
}

data "coder_parameter" "jupyter" {
  name        = "Jupyter IDE type"
  type        = "string"
  description = "What type of Jupyter do you want?"
  mutable     = true
  default     = "lab"
  icon        = "/icon/jupyter.svg"

  option {
    name = "Jupyter Lab"
    value = "lab"
    icon = "https://raw.githubusercontent.com/gist/egormkn/672764e7ce3bdaf549b62a5e70eece79/raw/559e34c690ea4765001d4ba0e715106edea7439f/jupyter-lab.svg"
  }
  option {
    name = "Jupyter Notebook"
    value = "notebook"
    icon = "https://codingbootcamps.io/wp-content/uploads/jupyter_notebook.png"
  }       
}

locals {
  jupyter-type-arg = "${data.coder_parameter.jupyter.value == "notebook" ? "Notebook" : "Server"}"
}

variable "api_key" {
  description = <<-EOF
  Arbitrary API Key to access Internet datasets (optional)

  EOF
  default=""
}

resource "coder_agent" "dev" {
  arch           = "amd64"
  os             = "linux"

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.

# 2023-07-12 commenting out since fails on docker
#  metadata {
#    display_name = "CPU Usage"
#    key          = "0_cpu_usage"
#    script       = "coder stat cpu"
#    interval     = 10
#    timeout      = 1
#  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  display_apps {
    vscode = false
    vscode_insiders = false
    ssh_helper = false
    port_forwarding_helper = false
    web_terminal = true
  }

  env = { 
    "DOTFILES_URL" = data.coder_parameter.dotfiles_url.value != "" ? data.coder_parameter.dotfiles_url.value : null
#    "http_proxy" = "http://193.197.95.183:2080"
#    "https_proxy" = "http://193.197.95.183:2080"
    }
  startup_script_behavior = "blocking"
  startup_script_timeout = 300  
  startup_script  = <<EOT
#!/bin/sh

# start jupyter 
jupyter ${data.coder_parameter.jupyter.value} --${local.jupyter-type-arg}App.token="" --ip="*" >/dev/null 2>&1 &

# add some Python libraries
pip3 install --user pandas &

# clone repo
#if [ ! -d "pandas_automl" ]; then
#  mkdir -p ~/.ssh
#  ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
#  git clone --progress git@github.com:sharkymark/pandas_automl.git 
#fi

# install code-server
curl -fsSL https://code-server.dev/install.sh | sh
code-server --auth none --port 13337 >/dev/null 2>&1 &

# install VS Code extension into code-server
SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server --install-extension ms-toolsai.jupyter 

# use coder CLI to clone and install dotfiles
if [ -n "$DOTFILES_URL" ]; then
  echo "Installing dotfiles from $DOTFILES_URL"
  coder dotfiles -y "$DOTFILES_URL"
fi

  EOT  
}

resource "coder_app" "jupyter" {
  agent_id      = coder_agent.dev.id
  slug          = "j"  
  display_name  = "jupyter-${data.coder_parameter.jupyter.value}"
  icon          = "/icon/jupyter.svg"
  url           = "http://localhost:8888/"
  share         = "owner"
  subdomain     = true  

  healthcheck {
    url       = "http://localhost:8888/healthz"
    interval  = 10
    threshold = 20
  }  
}

resource "docker_image" "self-built" {
  name = "coder-jupyter"
  build {
    context = "./docker"
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.self-built.name
  # Uses lower() to avoid Docker restriction on container names.
  name     = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["10.3.13.101"]
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.dev.init_script, "127.0.0.1", "host.docker.internal")]

#  command = [
#    "sh", "-c",
#    <<EOT
#    trap '[ $? -ne 0 ] && echo === Agent script exited with non-zero code. Sleeping infinitely to preserve logs... && sleep infinity' EXIT
#    ${replace(coder_agent.dev.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")}
#    EOT
#  ]

  env        = ["CODER_AGENT_TOKEN=${coder_agent.dev.token}", "API_KEY=${var.api_key}"]
#, "http_proxy=http://193.197.95.183:2080", "https_proxy=http://193.197.95.183:2080"]
  volumes {
    container_path = "/home/coder/"
    volume_name    = docker_volume.coder_volume.name
    read_only      = false
  }  
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
}

resource "docker_volume" "coder_volume" {
  name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
}


resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id   
  item {
    key   = "image"
    value = "codercom/enterprise-jupyter:ubuntu"
  }
  item {
    key   = "repo cloned"
    value = "docker.io/sharkymark/pandas_automl.git"
  }  
  item {
    key   = "jupyter"
    value = "${data.coder_parameter.jupyter.value}"
  }    
}