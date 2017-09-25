# vim:set syntax=sh et sw=4:

# dump remote server SSL/TLS certificates using openssl
_openssl_dump_remote_certs() {
    echo | openssl s_client -showcerts -connect $1:443 | openssl x509 -text -noout
}

