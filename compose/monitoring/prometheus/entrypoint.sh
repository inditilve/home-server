#!/bin/sh
envsubst < /etc/prometheus/prometheus.yml.template > /etc/prometheus/prometheus.yml
exec prometheus --config.file=/etc/prometheus/prometheus.yml