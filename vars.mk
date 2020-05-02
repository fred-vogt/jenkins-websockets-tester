SHELL=/bin/bash

JDK_VERSION=jdk8
#JDK_VERSION=jdk11

SERVER_IMAGE_NAME=jenkins-server
AGENT_IMAGE_NAME=jenkins-agent

HTTP_PORT=8080
HTTPS_PORT=8443
HTTP2_PORT=9443

SERVER_DEBUGGER_PORT=8000
AGENT_DEBUGGER_PORT=9000
CLI_DEBUGGER_PORT=7000

AGENT_NAME=127.0.0.1

RESOURCE_URL=https://127.0.0.1:$(HTTPS_PORT)

#
# Jenkins Server .war file / base image docker build settings
#
JENKINS_DOCKER_GITHUB=git@github.com:jenkinsci/docker.git
JENKINS_DOCKER_BRANCH=master
JENKINS_UID=8008
JENKINS_GID=8008

JENKINS_VERSION=2.234
RELEASE_DATE=2020-04-27
JENKINS_SHA=481ecc74bd6e5df1f32fe6acac59b0cf5e49790c3c2c48ee124ce469d133f4c0
JETTY_VERSION=9.4.26.v20200117
REMOTING_VERSION=4.3

SERVER_VERSION=$(JENKINS_VERSION)-$(RELEASE_DATE)-$(JDK_VERSION)
AGENT_VERSION=$(JENKINS_VERSION)-$(RELEASE_DATE)-$(JDK_VERSION)

#
# Use: make checksum-jenkins-war
#
JENKINS_WAR_DOWNLOAD_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/$(JENKINS_VERSION)/jenkins-war-$(JENKINS_VERSION).war

user_name=$(shell whoami)
group_name=$(shell id -g -n $(user_name))
user_id=$(shell id -u)
group_id=$(shell id -g)

JENKINS_CLI_JAR=$(CURDIR)/target/jenkins-cli.jar
JENKINS_CLI_AUTH=$(HOME)/.jenkins/auth

DOCKER_NETWORK=jenkins

TLS_CONFIG=$(HOME)/.jenkins/tls
TRUST_STORE=/var/lib/jenkins/truststore.jks

HOOK_SCRIPTS=$(CURDIR)/images/server/hook-scripts
CASC_CONFIG=$(CURDIR)/images/server/files/jenkins.yaml

EXTRA_SERVER_OPTS=\
-Djavax.net.ssl.trustStore=/var/jenkins_home/tls/truststore.jks \
-Djavax.net.ssl.trustStorePassword=jenkins \
-Djava.util.logging.config.file=/var/jenkins_home/logging.properties

EXTRA_CLIENT_OPTS=\
-Djavax.net.ssl.trustStore=/var/lib/jenkins/truststore.jks \
-Djavax.net.ssl.trustStorePassword=jenkins \
-Djava.util.logging.config.file=/var/lib/jenkins/logging.properties

EXTRA_AGENT_OPTS=\
-Djavax.net.ssl.trustStore=/var/lib/jenkins/truststore.jks \
-Djavax.net.ssl.trustStorePassword=jenkins \
-Djava.util.logging.config.file=/var/lib/jenkins/logging.properties
