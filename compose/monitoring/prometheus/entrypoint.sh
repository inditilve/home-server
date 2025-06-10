#!/bin/sh
apt-get update && apt-get install -y gettext-base
envsubst < /etc/prometheus/prometheus.yml.template > /etc/prometheus/prometheus.yml
exec prometheus --config.file=/etc/prometheus/prometheus.yml