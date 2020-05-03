import jenkins.model.JenkinsLocationConfiguration

/*
$JENKINS_HOME/jenkins.model.JenkinsLocationConfiguration.xml

<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>{ADMIN_EMAIL}</adminAddress>
  <jenkinsUrl>{JENKINS_URL}</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>
*/

def jlc = JenkinsLocationConfiguration.get()

def serverUrl = System.env.SERVER_URL

if (jlc.getUrl() != serverUrl) {
    println "Configured jenkins.model.JenkinsLocationConfiguration::url => ${serverUrl}"

    jlc.setUrl(serverUrl)
}
