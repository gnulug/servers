# GLUG Servers

This repo contains a Docker Compose setup for various services deployed on GLUG servers.

The top-level `compose.yaml` includes compose files for all services that should be deployed.

The services included are:
- **Caddy**: Acts as the top-level reverse proxy for all other services
- **Arch Mirror**: Hosts an Arch Linux mirror

The `volumes` directory contains persistent data that services can mount into their containers.
Folders within this directory are generally symlinked to locations in `/data`, which contains mounted RAID virtual disks.
