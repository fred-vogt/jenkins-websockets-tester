#!/bin/bash 

set -euo pipefail

usage_message="
Usage $0 <output-folder> [extra-SANs...]

Example:

$0 ~/.jenkins/tls IP:192.168.23.10 DNS:jenkins-server
"

output_dir=${1?"<output-folder> required.${usage_message}"}; shift
additional_sans=
if [ "$#" -gt 0 ]; then 
    for additional_san in "$@"; do
    	additional_sans+=",${additional_san}"
    done
fi

openssl req \
        -newkey rsa:2048 \
        -nodes \
        -keyout "${output_dir}/server-key.pem" \
        -x509 \
        -days 30 \
        -out "${output_dir}/server-cert.pem" \
        -subj "/C=US/ST=CA/L=San Francisco/O=cicdenv/OU=local/CN=localhost/emailAddress=jenkins@cicdenv.com" \
        -reqexts SAN \
        -extensions SAN \
        -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:localhost,IP:127.0.0.1${additional_sans}\n")) \
        -addext "basicConstraints=CA:TRUE" \
        -passin "pass:jenkins"

openssl rsa \
        -in "${output_dir}/server-key.pem" \
        -out "${output_dir}/server-rsa.pem"
openssl x509 \
        -in "${output_dir}/server-cert.pem" \
        -text \
        -noout
chmod o+r "${output_dir}/server-rsa.pem"

openssl pkcs12 \
        -export \
        -out "${output_dir}/server.pfx" \
        -inkey "${output_dir}/server-rsa.pem" \
        -in "${output_dir}/server-cert.pem" \
        -password "pass:jenkins"

rm -f "${output_dir}/truststore.jks"
cp "/usr/lib/jvm/java-11-openjdk/lib/security/cacerts" "${output_dir}/truststore.jks"
chmod u+w "${output_dir}/truststore.jks"
keytool -storepasswd \
        -new "jenkins" \
        -keystore "${output_dir}/truststore.jks" \
        -storepass "changeit"
keytool -import \
        -file "${output_dir}/server-cert.pem" \
        -alias "jenkins-server" \
        -trustcacerts \
        -noprompt \
        -storepass "jenkins" \
        -storetype "jks" \
        -keystore "${output_dir}/truststore.jks"
keytool -list -keystore "${output_dir}/truststore.jks" -storepass "jenkins"
keytool -list -keystore "${output_dir}/truststore.jks" -storepass "jenkins" -rfc -alias "jenkins-server"
