data "coder_workspace" "me" {}

resource "coder_agent" "coder" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/coder"
  startup_script = <<-EOF
pip3 install jupyterlab
$HOME/.local/bin/jupyter lab --ServerApp.token='' --ip='*'
EOF
}

resource "coder_app" "jupyter" {
  agent_id     = coder_agent.coder.id
  slug         = "jupyter"
  display_name = "JupyterLab"
  url          = "http://localhost:8888"
  icon         = "/icon/jupyter.svg"
  share        = "owner"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:8888/healthz"
    interval  = 5
    threshold = 10
  }
