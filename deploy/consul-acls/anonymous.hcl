# Default all keys to read-only
key "" {
    policy = "read"
}

key "vault" {
    policy = "deny"
}

key "secret" {
    policy = "deny"
}

key "private" {
    policy = "deny"
}

key "protect" {
    policy = "deny"
}

key "secure" {
    policy = "deny"
}

# Allow discovery of all services
service "" {
    policy = "read"
}

