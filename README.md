# Home Server

This is my current home lab/server setup, mainly consisting of docker compose stacks and Ansible scripts used to automate my setup from a bare-metal Ubuntu Server install.

The idea is to capture the steps required to set all of this up, with clean docker compose stacks.
This is a work [in progress](https://github.com/inditilve/home-server/issues)!



## Service Stacks
* [Media Apps](https://github.com/inditilve/home-server/tree/master/media/apps) - Plex and Audiobookshelf
* [Media Services](https://github.com/inditilve/home-server/tree/master/media/services) - Media Monitoring Stack
* [Monitoring](https://github.com/inditilve/home-server/tree/master/monitoring) - Grafana, Prometheus (with Node Exporter), Portainer, Watchtower
* [Networking](https://github.com/inditilve/home-server/tree/master/tailscale) - Tailscale setup for secure remote access + nginx-proxy-manager for reverse proxy
* [Dashboard](https://github.com/inditilve/home-server/tree/master/dashboard) - Customized Homepage dashboard for easy access to all my self-hosted services


## Implementation Details
### Ubuntu Post-Install Steps
- [Install latest Docker (uninstall older one)](https://docs.docker.com/engine/install/ubuntu/)
- Install Prometheus Node Exporter via systemctl and not docker, since it's easier to monitor the host's internals this way:
    ``sudo apt install prometheus-node-exporter``

### ZFS Setup
I've setup a pool with 2 main datasets relevant to this server configuration, and their mounts, as follows - 

```
storage_pool/docker -> /var/lib/docker
storage_pool/data -> /data
```

For any config related data, I have opted for named volumes which will by default be stored in ``/var/lib/docker``, whereas all media content lives under /data, and the compose volumes are mounted accordingly.

### Setup Home Server Stacks
- Clone this repository
- Replace ``indika-media`` with the hostname this setup will run on if required (I could not use profile/env variables for this as prometheus config does not seem to support envsubst)
- Replace ``TS_AUTHKEY`` in tailscale/.env with your Tailscale Auth Key which can be obtained from your tailnet settings
- Navigate to tailscale folder and bring it up first with ``docker compose up -d``
- Similarly, navigate to the other folders and bring up the respective compose stacks
- Then run the necessary tailscale serve commands to get TLS + clean URLs; Eg - 
```
docker exec tailscale tailscale serve --set-path grafana http://grafana:3000
docker exec tailscale tailscale serve --set-path portainer https://portainer:9443
```

### Networking
I'm using tailscale and a docker network ``tailscale-net`` to hook up all the services via tailscale and have them communicate with each other via Docker DNS. The reason for this choice is that I prefer Docker DNS's simple inter-container communication with ``container-name:port`` addresses. 

**Note**: This is in contrast with using ``network_mode:service:tailscale``) which would disable Docker DNS and force all docker services to only communicate via Tailscale. If I opt for disabling Docker DNS and using Tailscale's MagicDNS instead, then I'd have to also assign static IPs to each container, and then reference those when doing inter-container communication.


### Service configuration
Note that I haven't listed out how to configure each and every service I'm using, most of it can be found in the respective service's docs. Just listing the gotchas for now -
- Ensure that docker volume mount paths are consistent across services. Eg, ``/data/media/tv`` contains TV shows on my server, and different services have different expected paths that the above path needs to be mounted to
- My Grafana Node Exporter dashboard is a heavily pared down version of [this famous one](https://grafana.com/grafana/dashboards/1860-node-exporter-full/), import this after configuring prometheus as a data source within Grafana. My main use case is to monitor my zfs datasets, memory usage, cpu temperature (hence node exporter), cpu usage, network usage, etc


## Hardware Specs
- **OS \-** Ubuntu 24.04.2 LTS
- **CPU \-** Intel i5-4690K
- **Motherboard \-** ASUS Z97-Pro WiFi AC (6 SATA ports; currently using 3)
- **GPU \-** GTX970 (to be used for hardware-accelerated Plex transcoding)
- **RAM \-** 32GB DDR3
- **Cooling \-** Corsair H100i AIO attached on top with 2 fans on the radiator as exhaust
- **Boot Drive \-** 256GB SATA SSD
- **Storage Drives \-** 1TB SATA SSD and 2TB SATA SSD
- **PSU \-** 750W
- **Case \-** NZXT H440i
- **Fans \-** 3 Front intake, 1 rear exhaust

