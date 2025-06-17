#!/bin/bash
set -e

echo "Resetting any existing Tailscale Serve routes on port 443..."
docker exec tailscale tailscale serve reset

echo "Mounting root homepage..."
docker exec tailscale tailscale serve --bg --https=443 http://localhost:3001

declare -A routes=(
  ["/audiobookshelf"]="http://localhost:13378"
  ["/overseerr"]="http://localhost:5055"
  ["/prowlarr"]="http://localhost:9696"
  ["/sonarr"]="http://localhost:8989"
  ["/radarr"]="http://localhost:7878"
  ["/readarr"]="http://localhost:8787"
  ["/qbittorrent"]="http://localhost:8080"
  ["/grafana"]="http://localhost:3000"
  ["/prometheus"]="http://localhost:9090"
  ["/portainer"]="https://localhost:9443"
)

echo "Mounting services via Tailscale Serve on port 443..."
for path in "${!routes[@]}"; do
  echo "→ Serving $path → ${routes[$path]}"
  docker exec tailscale tailscale serve --bg --https=443 --set-path "$path" "${routes[$path]}"
done

echo "✅ All services are now live under ${TAILSCALE_URL}"