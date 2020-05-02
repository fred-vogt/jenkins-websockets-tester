# jenkins-websockets-tester
Local linux, mac websockets cli/agent test project.

## Purpose
For testing websocket+JDK11 timeout issues when using HTTPS
* [JENKINS-61212](https://issues.jenkins-ci.org/browse/JENKINS-61212)

## Usage

### Setup
```bash
# Create/Renew self signed cert
$ make build-tls tls import-cert

# Docker volumes
$ make volumes
```

NOTE: run `make clean` when switching between JDK versions

### JDK 8
```bash
# terminal #1
$ make JDK_VERSION=jdk8 build-server run-server

# terminal #2
$ make JDK_VERSION=jdk8 build-agent run-agent
```

### JDK 11
```bash
# terminal #1
$ make JDK_VERSION=jdk11 build-server run-server

# terminal #2
$ make JDK_VERSION=jdk11 build-agent run-agent
```
