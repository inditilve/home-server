#!/bin/bash

# Define root-level folders to restart, ordered by restart priority
ROOT_FOLDERS=(
    "networking"
    "dashboard"
    "monitoring"
    "media"
)

echo "🚀 Restarting services..."

for FOLDER in "${ROOT_FOLDERS[@]}"; do
    echo "🔄 Processing $FOLDER..."

    # Find all docker-compose.yml files within the folder (including subfolders)
    find ../$FOLDER -type f -name "docker-compose.yaml" | while read COMPOSE_FILE; do
        COMPOSE_DIR=$(dirname "$COMPOSE_FILE")

        echo "🔁 Restarting services in $COMPOSE_DIR..."
        cd "$COMPOSE_DIR" || exit 1
        docker compose down
        docker compose up -d
    done
done

echo "✅ All services restarted successfully!"