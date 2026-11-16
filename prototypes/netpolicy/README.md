# PROTOTYPE: internet-only egress for the container sandbox (#138, task 5)

Throwaway. Answers one question: can a sandboxed job keep internet access while the host, the LAN
and metadata-like addresses are blocked, with each runtime, and what does it cost to set up?

- `docker.sh up|down`: rootful Docker. A dedicated `octopus-ci` network (`br-octopus`, 10.231.0.0/24),
  `DOCKER-USER` drops new connections from it to private, link-local and CGNAT ranges, `INPUT` drops
  everything from `br-octopus` to the host. Needs sudo once. Run jobs with network `octopus-ci`.
- `podman.sh up|down|show`: rootless Podman. An nftables table inside Podman's own rootless network
  namespace (no sudo): the same forward drops, and the bridge gateway only answers DNS. The namespace
  goes away with the last container, so keep one running first:
  `podman run -d --rm --name octopus-netkeeper --network bridge docker.io/library/ubuntu:24.04 sleep infinity`.

Check with `tests/test_ci_sandbox_runtime.py` (`OCTOPUS_TEST_CONTAINER_NETWORK` selects the network):
the two task-5 strict xfails turn into XPASS(strict) and the internet control still passes.
