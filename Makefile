include $(CURDIR)/vars.mk

builds: build-server build-agent build-tls

UNAME=$(shell uname)
ifeq ($(UNAME), Linux)
    include $(CURDIR)/Makefile-Linux.mk
endif
ifeq ($(UNAME), Darwin)
    include $(CURDIR)/Makefile-Darwin.mk
endif

build-server: build-jenkinsci-docker
	# Build & Tag by version
	docker build -t "$(SERVER_IMAGE_NAME):$(SERVER_VERSION)"  \
	    --build-arg='jettyVersion=$(JETTY_VERSION)'           \
	    images/server                                         \
	    -f images/server/Dockerfile-$(JDK_VERSION)

	# Tag as latest
	docker tag "$(SERVER_IMAGE_NAME):$(SERVER_VERSION)" "$(SERVER_IMAGE_NAME):latest"

build-agent: build-server
	# Build & Tag by version
	docker build -t "$(AGENT_IMAGE_NAME):$(AGENT_VERSION)"  \
	    --build-arg='jenkinsVersion=$(JENKINS_VERSION)'     \
	    --build-arg='REMOTING_VERSION=$(REMOTING_VERSION)'  \
	    --build-arg='uid=$(JENKINS_UID)'                    \
	    --build-arg='gid=$(JENKINS_GID)'                    \
	    images/agent                                        \
	    -f images/agent/Dockerfile-$(JDK_VERSION)

	# Tag as latest
	docker tag "$(AGENT_IMAGE_NAME):$(AGENT_VERSION)" "$(AGENT_IMAGE_NAME):latest"

build-jenkinsci-docker: pull-jenkinsci-docker
	if [[ ! -f images/server/jenkins-ci.docker/Dockerfile-jdk8 ]]; then  \
		cp images/server/jenkins-ci.docker/Dockerfile                    \
	          images/server/jenkins-ci.docker/Dockerfile-jdk8;           \
	fi
	docker build -t jenkins-upstream-$(JDK_VERSION):latest  \
	    --build-arg='uid=$(JENKINS_UID)'                    \
	    --build-arg='gid=$(JENKINS_GID)'                    \
	    --build-arg='JENKINS_VERSION=$(JENKINS_VERSION)'    \
	    --build-arg='JENKINS_SHA=$(JENKINS_SHA)'            \
	    --build-arg='agent_port=$(AGENT_PORT)'              \
	    images/server/jenkins-ci.docker                     \
	    -f images/server/jenkins-ci.docker/Dockerfile-$(JDK_VERSION)

pull-jenkinsci-docker:
	if [[ ! -d images/server/jenkins-ci.docker ]]; then \
	    git clone --depth 1 $(JENKINS_DOCKER_GITHUB) --branch $(JENKINS_DOCKER_BRANCH) images/server/jenkins-ci.docker; \
	else \
	    if [[ ! "master" == "$(shell if [ -d images/server/jenkins-ci.docker ]; then git --git-dir images/server/jenkins-ci.docker/.git rev-parse --abbrev-ref HEAD; fi)" ]]; then \
	        rm -rf images/server/jenkins-ci.docker; git clone --depth 1 $(JENKINS_DOCKER_GITHUB) --branch $(JENKINS_DOCKER_BRANCH) images/server/jenkins-ci.docker; \
	    fi; \
	fi

build-tls:
	docker build -t "tls-tool"                 \
	    --build-arg nonroot_user=$(user_name)  \
	    --build-arg  nonroot_uid=$(user_id)    \
	images/tls

print-server-cert:
	openssl s_client -showcerts -servername localhost -connect localhost:8443 </dev/null \
	| openssl x509 -text

cli-install:
	mkdir -p $(shell dirname $(JENKINS_CLI_JAR))
	curl -sk $(SERVER_URL)/jnlpJars/jenkins-cli.jar -o "$(JENKINS_CLI_JAR)"

cli-help: cli-install
	@docker run -it --rm                           \
	    -v $(JENKINS_CLI_JAR):/jenkins-cli.jar:ro  \
	    openjdk:jre-alpine                         \
	    java -jar /jenkins-cli.jar                 \
	    help

EDIT_IN_PLACE=$(shell if uname -s | grep Darwin > /dev/null; then echo '-i' \'\'; else echo '-i'; fi)
SHA256_CMD=$(shell if uname -s | grep Darwin > /dev/null; then echo 'shasum -a 256'; else echo sha256sum; fi)

checksum:
	_sha=$$(curl -fsSL $(JENKINS_WAR_DOWNLOAD_URL) | $(SHA256_CMD) | awk '{ print $$1 }');  \
	sed $(EDIT_IN_PLACE) "s/^JENKINS_SHA=.*$$/JENKINS_SHA=$${_sha}/" "$(CURDIR)/vars.make"

export-config:
	export CSRF_CRUMB=$$(curl -skL                                                           \
	    -c $(CURDIR)/cli-cookies.txt                                                         \
	    -u "$(shell cat $(JENKINS_CLI_AUTH))"                                                \
	    "$(SERVER_URL)"'/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)'  \
	);                                                                                       \
	curl -skL                                                                                \
	    -b $(CURDIR)/cli-cookies.txt                                                         \
	    -u "$(shell cat $(JENKINS_CLI_AUTH))"                                                \
	    -H "$$CSRF_CRUMB"                                                                    \
	    -X POST                                                                              \
	    "$(SERVER_URL)/configuration-as-code/export"                                         \
	    | sed -E -e 's/(\s+secret:\s+)".+"/\1"..."/'                                         \
	             -e 's/(\s+password:\s+)".+"/\1"..."/'                                       \
	             -e 's/(\s+clientSecret:\s+)".+"/\1"..."/'                                   \
	    | tee $(CURDIR)/snapshots/config/$(SERVER_VERSION).yaml

clean: stop-agent stop-server clean-server clean-agent #secrets-files

stop-agent:
	-@docker stop $$(docker ps -a -q -f name=jenkins-agent) &>/dev/null || true
	-@docker rm   $$(docker ps -a -q -f name=jenkins-agent) &>/dev/null || true

stop-server:
	-@docker stop $$(docker ps -a -q -f name=jenkins-server) &>/dev/null || true
	-@docker rm   $$(docker ps -a -q -f name=jenkins-server) &>/dev/null || true

clean-server:
	docker run --rm \
	    -v jenkins-server-home:/var/jenkins_home \
	    ubuntu \
	    bash -c "rm -rf /var/jenkins_home/*"

clean-agent:
	docker run --rm \
	    -v jenkins-agent-workspace:/var/lib/jenkins/workspace \
	    ubuntu \
	    bash -c "rm -rf /var/lib/jenkins/workspace/*"

clean-images:
	for image in $(SERVER_IMAGE_NAME)  \
	             jenkins-upstream      \
	             $(AGENT_IMAGE_NAME)   \
	; do  \
	    if [ "$$(docker images -q $$image | wc -l)" -gt 0 ]; then                 \
	        for img_id in $$(docker images -q $$image | uniq); do                 \
	            for dep_id in                                                     \
	                    $$(for id in $$(docker images -q); do                     \
	                        docker history $$id | grep -q $$img_id && echo $$id;  \
	                    done | sort -u); do                                       \
	                docker rmi --force $$dep_id;                                  \
	            done;                                                             \
	            docker rmi --force $$img_id;                                      \
	        done;                                                                 \
	    fi;                                                                       \
	done

run-server-bash:
	docker run --rm -it --entrypoint=/bin/bash "$(SERVER_IMAGE_NAME)"

run-agent-bash:
	docker run --rm -it --network=host --entrypoint=/bin/bash "$(AGENT_IMAGE_NAME)-local"

debug-agent:
	docker exec -it --user $(JENKINS_UID) -w '/var/lib/jenkins' "$(AGENT_IMAGE_NAME)-local" /bin/bash

debug-server:
	docker exec -it --user $(JENKINS_UID) -w '/var/jenkins_home' "$(SERVER_IMAGE_NAME)" /bin/bash
