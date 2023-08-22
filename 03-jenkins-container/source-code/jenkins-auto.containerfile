FROM jenkins/jenkins:almalinux
USER root

# Ensure system is up-to-date
RUN yum -y update &&\
    yum -y upgrade &&\
    yum -y clean all &&\
    yum -y autoremove

# Skip initial setup
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false

# Use a Groovy script to configure the admin user
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d

# Install the recommended plugins, plus the Subversion and JUnit plugins
# https://github.com/jenkinsci/jenkins/blob/master/core/src/main/resources/jenkins/install/platform-plugins.json
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Ensure the passwd utility is installed
RUN yum -y install passwd

# Create a root password
RUN echo Change.Me.321 | passwd root --stdin

# Install Python for Flask demo
RUN yum -y install python39

# Install Java, fontconfig and Node.js (for SonarScanner)
RUN yum -y install java-17-openjdk-devel fontconfig
RUN yum -y install nodejs
RUN npm cache clean -f &&\
    npm install -g n &&\
    n stable

# Ensure the system is still up-to-date
RUN yum -y update

# Allow traffic through port 8080 (Jenkins)
EXPOSE 8080
