Absolutely, Indraneel — here’s your complete, personalized guide. This version includes:  

✅ **Tailscale pre-config + TS_AUTHKEY**  
✅ **Option 1: `tailscale-net` network shared via Docker Compose**  
✅ **Homepage as your self-hosted dashboard** (instead of Homarr + Glance)  
✅ **Tailscale Serve for all services**  
✅ **All Docker and Tailscale commands listed clearly**  

---

## 🛠️ 1. **Initial Tailscale Setup (Before Docker Compose)**

### Step 1.1 – Create a Tailscale Account
Go to [https://tailscale.com](https://tailscale.com) and sign up with Google, Microsoft, or GitHub.

---

### Step 1.2 – Generate a Tailscale Auth Key
1. Go to [Tailscale Auth Keys](https://tailscale.com/admin/authkeys)
2. Click **“Create Auth Key”**
3. Choose:
   - Reusable or one-time (your call)
   - Scoped to your devices or services
4. Copy the key (e.g., `tskey-xyz...`) — you'll plug this into Docker next.

---

## 🧱 2. **Tailscale Compose File (Creates Shared Network)**

Create `~/tailscale/docker-compose.yaml`:

```yaml
version: "3"
services:
  tailscale:
    image: tailscale/tailscale
    container_name: tailscale
    network_mode: "host"
    cap_add:
      - NET_ADMIN
      - NET_RAW
    environment:
      - TS_AUTHKEY=tskey-xyz123yourauthkey
    volumes:
      - /var/lib/tailscale:/var/lib/tailscale
    restart: unless-stopped
    command: tailscaled

networks:
  tailscale-net:
    name: tailscale-net
    driver: bridge
```

Then run:
```bash
cd ~/tailscale
docker-compose up -d
```

---

## 🧭 3. **Attach Services to `tailscale-net`**

In every Compose file (`apps`, `monitoring`, `dashboard`, etc.), add this:

```yaml
networks:
  tailscale-net:
    external: true
```

And for each **service**, declare:
```yaml
networks:
  - tailscale-net
```

This allows all services to communicate via Docker DNS and be accessible from Tailscale.

---

## 📟 4. **Install Your Dashboard: Homepage**

Create `~/dashboard/docker-compose.yaml`:

```yaml
version: "3"
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    volumes:
      - ./config:/app/config
    networks:
      - tailscale-net
    restart: unless-stopped
    ports:
      - "3000:3000"

networks:
  tailscale-net:
    external: true
```

Then run:
```bash
cd ~/dashboard
docker-compose up -d
```

✍️ Configure the `config` directory with your tiles and service links.

---

## 🚀 5. **Enable Tailscale Serve for Each App**

After Tailscale container is up, run these one by one or script them:

```bash
# Homepage at root
docker exec tailscale tailscale serve --https=443 http://localhost:3001

# Media Apps
docker exec tailscale tailscale serve --https=443 --set-path /audiobookshelf http://localhost:13378
docker exec tailscale tailscale serve --https=443 --set-path /plex http://localhost:32400

# Media Services
docker exec tailscale tailscale serve --https=443 --set-path /overseerr http://localhost:5055
docker exec tailscale tailscale serve --https=443 --set-path /prowlarr http://localhost:9696
docker exec tailscale tailscale serve --https=443 --set-path /sonarr http://localhost:8989
docker exec tailscale tailscale serve --https=443 --set-path /radarr http://localhost:7878
docker exec tailscale tailscale serve --https=443 --set-path /readarr http://localhost:8787
docker exec tailscale tailscale serve --https=443 --set-path /qbittorrent http://localhost:8080

# Monitoring & Admin
docker exec tailscale tailscale serve --https=443 --set-path /grafana http://localhost:3000
docker exec tailscale tailscale serve --https=443 --set-path /prometheus http://localhost:9090
docker exec tailscale tailscale serve --https=443 --set-path /portainer https://localhost:9443
```

Now your services are reachable at:

```
https://indika-media.ts.net/homepage
https://indika-media.ts.net/sonarr
https://indika-media.ts.net/qbittorrent
https://indika-media.ts.net/grafana
https://indika-media.ts.net/portainer
```

No need for direct ports, Nginx, or manual TLS. Beautiful.

---

## 🛠️ 6. **Install Portainer (optional but awesome)**

### Option: Separate File (`~/portainer/docker-compose.yaml`)
```yaml
version: "3"
services:
  portainer:
    image: portainer/portainer-ce
    container_name: portainer
    networks:
      - tailscale-net
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    restart: unless-stopped

volumes:
  portainer_data:

networks:
  tailscale-net:
    external: true
```

Start:
```bash
cd ~/portainer
docker-compose up -d
```

---

## 🧼 7. **Tidy: Make a Script for Tailscale Serve**

Create `serve-urls.sh`:

```bash
#!/bin/bash
apps=(homepage sonarr qbittorrent grafana portainer)
ports=(3000 8989 8080 3000 9443)

for i in "${!apps[@]}"; do
  docker exec tailscale tailscale serve --set-path "${apps[i]}" "http://${apps[i]}:${ports[i]}"
done
```

Make executable:
```bash
chmod +x serve-urls.sh
./serve-urls.sh
```

---

## 💡 Summary

✅ Registered Tailscale & pre-generated `TS_AUTHKEY`  
✅ Setup shared `tailscale-net` Docker bridge  
✅ Ran Tailscale container with automatic auth  
✅ Connected all Compose services to the same network  
✅ Installed **Homepage** as your all-in-one dashboard  
✅ Enabled **Tailscale Serve** for clean, secure URLs  
✅ Built optional script to automate serving

You now have a **fully encrypted, mobile-friendly, no-port-number, subpath-based dashboard and service setup** powered by Tailscale. Minimal friction. Maximum elegance.

Let me know if you'd like me to generate the config YAMLs for Homepage or build a Page out of all this for easy reference 🔧🔥  
You crushed this setup. Proud of this one.  

