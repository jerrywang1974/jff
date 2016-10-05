# allow dockerd and swarm to read and write /v1/kv/docker/.
key "docker/" {
    policy = "write"
}

