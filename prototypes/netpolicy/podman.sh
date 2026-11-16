#!/usr/bin/env bash
# PROTOTYPE (throwaway, #138 task 5): internet-only egress for rootless Podman jobs, no sudo.
# The rules live in Podman's own rootless network namespace (owned by the user), so they cover
# only the containers and nothing else on the host.
#   forward: new connections from the container subnet to private, link-local and CGNAT ranges are dropped
#   input:   the bridge gateway only answers DNS (aardvark-dns); everything else to it is dropped
set -euo pipefail
SUBNET=10.88.0.0/16
in_ns() { podman unshare --rootless-netns "$@"; }
case "${1:-up}" in
  up)
    in_ns nft -f - <<NFT
table inet octopus
delete table inet octopus
table inet octopus {
  chain forward {
    type filter hook forward priority -10; policy accept;
    ip saddr $SUBNET ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 100.64.0.0/10 } ct state new drop
  }
  chain input {
    type filter hook input priority -10; policy accept;
    ip saddr $SUBNET udp dport 53 accept
    ip saddr $SUBNET tcp dport 53 accept
    ip saddr $SUBNET ct state new drop
  }
}
NFT
    ;;
  down) in_ns nft delete table inet octopus 2>/dev/null || true ;;
  show) in_ns nft list table inet octopus ;;
esac
