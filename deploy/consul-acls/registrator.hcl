service "" {
    policy = "write"
}

# Never overwrite Consul service
service "consul" {
    policy = "read"
}

# Never overwrite Vault service
service "vault" {
    policy = "read"
}

