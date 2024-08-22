Coder v2 Install
=========

This Ansible role installs Coder v2 on Ubuntu. It takes care of downloading the appropriate `.deb` package (either `amd64` or `arm64`), installing it, configuring the `coder.env` file, and enabling the service in `systemctl`.

If the `coder_http_address` has a port < 1024, the role will also set `cap_net_bind_service=+ep` capability on the `coder` executable to make it run on the port without running as root.  ***The capability will be lost on upgrade, unless you upgrade using this same role***.

Any configuration change can be done by adding the variables in your playbook and running it again.

You should make sure to upgrade `coder` with this role, or remember to run it after upgrading, else it will not be able to bind on a port < 1024 by default.

The role can also uninstall Coder, by setting the `coder_action` variable to `uninstall`.

Requirements
------------

- Ubuntu 18.04 (Bionic), 20.04 (Focal) or 22.04 (Jammy)
- Ansible 2.9 or higher

Role Variables
--------------

| Variable          | Default      | Required | Description                                           |
|-------------------|--------------|:--------:|-------------------------------------------------------|
| `coder_action`    | `install`     |    ✅    | The action for the Coder role (`install` or `uninstall`). |
| `coder_access_url`| *(none)*     |    ✅    | The access URL for the Coder instance.                |
| `coder_http_address` | `0.0.0.0:80` |  ❌  | The HTTP address for the Coder instance.              |
| `coder_tls_enable`| `false`      |    ❌    | Whether to enable TLS for the Coder instance.         |
| `coder_tls_address` | `0.0.0.0:443` |  ❌  | The TLS address for the Coder instance (included only if TLS is enabled). |


Dependencies
------------

None.

Example Playbooks
-----------------

**Simplest Playbook - Install**
```yaml
- hosts: servers
  vars:
    coder_access_url: "https://your-coder-access-url.example.com"
  roles:
    - thehedgefrog.coder_v2_install
```
This playbook will install Coder with the default configuration, using the provided access URL.

**Customized Install - Different Ports and Access URL**
```yaml
- hosts: servers
  vars:
    coder_access_url: "https://your-coder-access-url.example.com"
    coder_tls_enable: true
    coder_http_port: 8080
    coder_https_port: 8443
  roles:
    - thehedgefrog.coder_v2_install
```
This playbook will install Coder with custom HTTP and HTTPS ports, using the provided access URL.

**Uninstall Coder**
```yaml
- hosts: servers
  vars:
    coder_action: "uninstall"
  roles:
    - thehedgefrog.coder_v2_install
```
This playbook will uninstall Coder by setting the `coder_uninstall` variable to `true`. This will remove the service, .deb package, and configuration files.

License
-------

MIT
