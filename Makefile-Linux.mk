UNSECURE_URL=http://localhost:$(HTTP_PORT)
SERVER_URL=https://localhost:$(HTTPS_PORT)

run-agent:
	docker run --rm --name 'jenkins-agent' --init              \
	    --network host                                         \
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

run-server:
	docker run --rm --name 'jenkins-server'                     \
	    --network host                                          \
	    --env "SERVER_URL=$(SERVER_URL)"                        \
	    --env "RESOURCE_URL=$(RESOURCE_URL)"                    \
	    --env "EXTRA_SERVER_OPTS=$(EXTRA_SERVER_OPTS)"          \
	    -v jenkins-server-home:/var/jenkins_home                \
	    -v $(HOOK_SCRIPTS):/var/jenkins_home/init.groovy.d      \
	    -v $(CASC_CONFIG):/var/jenkins_home/jenkins.yaml        \
	    -v $(TLS_CONFIG):/var/jenkins_home/tls                  \
	    -h 'jenkins-server'                                     \
	    "$(SERVER_IMAGE_NAME)"

import-cert:
	certutil -d "sql:$(HOME)/.pki/nssdb" -D -n "jenkins-local" || true; \
	certutil -d "sql:$(HOME)/.pki/nssdb" -A -t "C,," -n "jenkins-local" -i "$(HOME)/.jenkins/tls/server-cert.pem"; \
	certutil -d "sql:$(HOME)/.pki/nssdb" -L; \

volumes:
	docker volume list | grep jenkins-server-home      >/dev/null || docker volume create --name jenkins-server-home;      \
	docker volume list | grep jenkins-agent-workspace  >/dev/null || docker volume create --name jenkins-agent-workspace;  \
	docker volume list | grep jenkins-agent-cache      >/dev/null || docker volume create --name jenkins-agent-cache;      \

rm-volumes:
	for vol in jenkins-server-home jenkins-agent-workspace jenkins-agent-cache; do \
	    if docker volume list | grep $$vol >/dev/null; then docker volume rm $$vol; fi; \
	done

DEFAULT_BROWSER=x-www-browser
ui:
	$(DEFAULT_BROWSER) $(SERVER_URL)

plugin-versions: cli-install
	@docker run -i --rm                                       \
	    -v $(JENKINS_CLI_JAR):/jenkins-cli.jar:ro             \
	    -v $(TLS_CONFIG):/tls:ro                              \
	    --net host                                            \
	    openjdk:jre-alpine                                    \
	    java                                                  \
	        "-Djavax.net.ssl.trustStore=/tls/truststore.jks"  \
	        "-Djavax.net.ssl.trustStorePassword=jenkins"      \
	        -jar /jenkins-cli.jar                             \
	        -s $(SERVER_URL)                                  \
	        -auth $(shell cat $(JENKINS_CLI_AUTH))            \
	        groovy = < snapshots/plugins/listPlugins.groovy   \
	| tee snapshots/plugins/$(SERVER_VERSION).txt
