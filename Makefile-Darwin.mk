UNSECURE_URL=http://$(IP_ADDRESS):$(HTTP_PORT)
SERVER_URL=https://$(IP_ADDRESS):$(HTTPS_PORT)

run-agent: network
	docker run --rm --name 'jenkins-agent' --init              \
	    --network '$(DOCKER_NETWORK)'                          \
	    -p $(DEBUGGER_PORT):$(AGENT_DEBUGGER_PORT)             \
	    --env "AGENT_NAME=$(AGENT_NAME)"                       \
	    --env "EXECUTORS=4"                                    \
	    --env "SERVER_URL=$(SERVER_URL)"                       \
	    --env "EXTRA_CLIENT_OPTS=$(EXTRA_CLIENT_OPTS)"         \
	    --env "EXTRA_AGENT_OPTS=$(EXTRA_AGENT_OPTS)"           \
	    -v jenkins-agent-workspace:/var/lib/jenkins/workspace  \
	    -v jenkins-agent-cache:/var/lib/jenkins/cache          \
	    -v $(TLS_CONFIG)/truststore.jks:$(TRUST_STORE)         \
	    -h 'jenkins-agent'                                     \
	    "$(AGENT_IMAGE_NAME)-local"

run-server: network
	docker run --rm --name 'jenkins-server'                     \
	    --network '$(DOCKER_NETWORK)'                           \
	    -p $(HTTP_PORT):$(HTTP_PORT)                            \
	    -p $(HTTPS_PORT):$(HTTPS_PORT)                          \
	    -p $(HTTP2_PORT):$(HTTP2_PORT)                          \
	    -p $(DEBUGGER_PORT):$(SERVER_DEBUGGER_PORT)             \
	    --env "SERVER_URL=$(SERVER_URL)"                        \
	    --env "RESOURCE_URL=$(RESOURCE_URL)"                    \
	    -v jenkins-server-home:/var/jenkins_home                \
	    -v $(HOOK_SCRIPTS):/var/jenkins_home/init.groovy.d      \
	    -v $(CASC_CONFIG):/var/jenkins_home/jenkins.yaml        \
	    -v $(TLS_CONFIG):/var/jenkins_home/tls                  \
	    -h 'jenkins-server'                                     \
	    "$(SERVER_IMAGE_NAME)"

network:
	if ! docker network inspect '$(DOCKER_NETWORK)' &>/dev/null; then  \
	    docker network create '$(DOCKER_NETWORK)';                     \
	fi

import-cert:
	sudo security add-trusted-cert \
	    -k /Library/Keychains/System.keychain \
	    -d "$(HOME)/.jenkins/tls/server-cert.pem"; \

volumes:
	_dpid=$(shell docker run --rm -i \
	    --privileged \
	    --pid=host \
	    debian \
	    nsenter -t 1 -m -u -n -i bash -c 'ctr -n services.linuxkit tasks ls | grep docker | awk '\''{print $$2}'\'); \
	docker run --rm -it \
	    --privileged \
	    --pid=host \
	    debian \
	    nsenter -t 1 -m -u -n -i bash -c 'ctr -n services.linuxkit tasks exec -t --exec-id '$$_dpid' docker sh -c '\''\
mkdir -p /var/jenkins_home /var/lib/jenkins/workspace /var/lib/jenkins/cache; \
docker volume list | grep jenkins-server-home      >/dev/null || docker volume create -o type=none -o o=bind -o device=/var/jenkins_home          --name jenkins-server-home;      \
docker volume list | grep jenkins-agent-workspace  >/dev/null || docker volume create -o type=none -o o=bind -o device=/var/lib/jenkins/workspace --name jenkins-agent-workspace;  \
docker volume list | grep jenkins-agent-cache      >/dev/null || docker volume create -o type=none -o o=bind -o device=/var/lib/jenkins/cache     --name jenkins-agent-cache       \
'\'; \

rm-volumes:
	for vol in jenkins-server-home jenkins-agent-workspace jenkins-agent-cache; do \
	    if docker volume list | grep $$vol >/dev/null; then docker volume rm $$vol; fi; \
	done
	if uname -s | grep Darwin > /dev/null; then \
	    _dpid=$(shell docker run --rm -i \
	        --privileged \
	        --pid=host \
	        debian \
	        nsenter -t 1 -m -u -n -i bash -c 'ctr -n services.linuxkit tasks ls | grep docker | awk '\''{print $$2}'\'); \
	    docker run --rm -it \
	        --privileged \
	        --pid=host \
	        debian \
	        nsenter -t 1 -m -u -n -i bash -c 'ctr -n services.linuxkit tasks exec -t --exec-id '$$_dpid' docker sh -c '\''\
rm -rf /var/jenkins_home /var/lib/jenkins/workspace /var/lib/jenkins/cache \
'\'; \
	fi

flush-agent-cache:
	_dpid=$(shell docker run --rm -i \
	    --privileged \
	    --pid=host \
	    debian \
	    nsenter -t 1 -m -u -n -i bash -c 'ctr -n services.linuxkit tasks ls | grep docker | awk '\''{print $$2}'\'); \
	docker run --rm -it \
	    --privileged \
	    --pid=host \
	    debian \
	    nsenter -t 1 -m -u -n -i bash -c 'ctr -n services.linuxkit tasks exec -t --exec-id '$$_dpid' docker sh -c '\''\
rm -rf /var/lib/jenkins/cache/* \
'\'; \

console:
	screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty

_PS1='🛠️ \[\033[1;36m\]\u@\h:\[\033[1;34m\]\w\[\033[0;35m\]\[\033[1;36m\]$$ \[\033[0m\]'
host:
	docker run --rm -it \
	    --privileged \
	    --pid=host \
	    --env PS1=$(_PS1) \
	    debian \
	    nsenter -t 1 -m -u -n -i bash

MAC_INTERFACE=en9

IP_ADDRESS=$(shell ipconfig getifaddr $(MAC_INTERFACE))
UNSECURE_URL=http://$(IP_ADDRESS):$(HTTP_PORT)
SERVER_URL=https://$(IP_ADDRESS):$(HTTPS_PORT)

ip-address:
	@echo $(IP_ADDRESS)

DEFAULT_BROWSER=open

ui:
	$(DEFAULT_BROWSER) $(SERVER_URL)

plugin-versions: cli-install
	@docker run -i --rm                                       \
	    -v $(JENKINS_CLI_JAR):/jenkins-cli.jar:ro             \
	    -v $(TLS_CONFIG):/tls:ro                              \
	    --net jenkins                                         \
	    openjdk:jre-alpine                                    \
	    java                                                  \
	        "-Djavax.net.ssl.trustStore=/tls/truststore.jks"  \
	        "-Djavax.net.ssl.trustStorePassword=jenkins"      \
	        -jar /jenkins-cli.jar                             \
	        -s $(SERVER_URL)                                  \
	        -auth $(shell cat $(JENKINS_CLI_AUTH))            \
	        groovy = < snapshots/plugins/listPlugins.groovy   \
	| tee snapshots/plugins/$(SERVER_VERSION).txt
