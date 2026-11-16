#!/usr/bin/env bash
# PROTOTYPE (throwaway, #138 task 5): internet-only egress for rootful Docker jobs.
# A dedicated bridge network with its own interface, then two host rules:
#   FORWARD (DOCKER-USER): new connections from the subnet to private, link-local and CGNAT ranges are dropped
#   INPUT: anything from the bridge interface to the host itself is dropped (host services, gateway)
set -euo pipefail
NET=octopus-ci SUBNET=10.231.0.0/24 IFACE=br-octopus
case "${1:-up}" in
  up)
    docker network inspect "$NET" >/dev/null 2>&1 || docker network create --driver bridge \
      --subnet "$SUBNET" -o com.docker.network.bridge.name="$IFACE" "$NET" >/dev/null
    for d in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10; do
      sudo iptables -C DOCKER-USER -s "$SUBNET" -d "$d" -m conntrack --ctstate NEW -j DROP 2>/dev/null \
        || sudo iptables -I DOCKER-USER -s "$SUBNET" -d "$d" -m conntrack --ctstate NEW -j DROP
    done
    sudo iptables -C INPUT -i "$IFACE" -j DROP 2>/dev/null || sudo iptables -I INPUT -i "$IFACE" -j DROP
    ;;
  down)
    for d in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10; do
      sudo iptables -D DOCKER-USER -s "$SUBNET" -d "$d" -m conntrack --ctstate NEW -j DROP 2>/dev/null || true
    done
    sudo iptables -D INPUT -i "$IFACE" -j DROP 2>/dev/null || true
    docker network rm "$NET" >/dev/null 2>&1 || true
    ;;
esac
