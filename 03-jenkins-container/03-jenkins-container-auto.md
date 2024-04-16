# Jenkins Container Demo (Automatic Setup)

These instructions will create a Jenkins container that is unlocked, configured with an admin user, and with the recommended plugins (plus Subversion and JUnit) already installed; it will not require you to perform the normal initial setup process for Jenkins. However, unlike the [Manual Setup](/03-jenkins-container/03-jenkins-container-manual.md), the containerfile will **NOT** enable an SSH service that can be accessed using Ansible. You will still be able to execute `sudo podman exec jenkins_node` commands, though.

- [Create and Add the Jenkins Server Container to the Network](#create-and-add-the-jenkins-server-container-to-the-network)
- [Access and Setup Jenkins](#access-and-setup-jenkins)

> **WARNING** -  This is only a proof-of-concept demo for a single user! Do not use for production.

-----

## Create and Add the Jenkins Server Container to the Network

For this tutorial, you will use the freely available AlmaLinux 8 image as the operating system for your containers. However, you may use other comparable images, such as CentOS, Rocky Linux, or a Red Hat's Universal Base Image (UBI) (subscription required).

1. Open a Terminal, if one is not already open.

2. Create a Groovy Hook Script. Jenkins will run this script after it starts up:

    ```bash
    touch init.groovy
    ```

3. Using an editor of your choice, open `init.groovy` and add the following code:

    ```groovy
    import jenkins.model.*
    import hudson.security.*

    def instance = Jenkins.getInstance()

    def hudsonRealm = new HudsonPrivateSecurityRealm(false)
    hudsonRealm.createAccount("jenkinsuser", "Change.Me.123")
    hudsonRealm.createAccount("admin", "Change.Me.321")
    instance.setSecurityRealm(hudsonRealm)

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)

    instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

    instance.save()
    ```

4. Create a file to hold the list of plugins you want Jenkins to use. The `jenkins-plugin-manager.jar` file will read the list and install the plugins after Jenkins starts up:

    ```bash
    touch plugins.txt
    ```

5. Using an editor of your choice, open `plugins.txt` and add the following plugins:

    **NOTE** - This is a list of Jenkins' default and recommended plugins. It also includes the Subversion and JUnit plugins, which you will need for this tutorial. However, you can customize this list to fit your needs.

    ```text
    cloudbees-folder
    antisamy-markup-formatter
    build-timeout
    credentials-binding
    timestamper
    ws-cleanup
    ant
    gradle
    workflow-aggregator
    github-branch-source
    pipeline-github-lib
    pipeline-stage-view
    git
    ssh-slaves
    matrix-auth
    pam-auth
    ldap
    email-ext
    mailer
    subversion
    junit
    ```

6. Create a containerfile:

    ```bash
    touch jenkins-auto.containerfile
    ```

7. Using an editor of your choice, open `jenkins-auto.containerfile` and add the following code:

    ```dockerfile
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
    ```

8. Build the image:

    > **NOTE** - Podman uses `/var/tmp` by default to download and build images. If a `No space left on device` error appears during the build, you can change the `image_copy_tmp_dir` setting in the `containers.conf` file, usually located in `/usr/share/containers/containers.conf`.

    ```bash
    # Optional; remove final and intermediate images if they exist
    sudo podman rmi jenkins_node_image --force
    sudo podman image prune --all --force
    # Build the image
    sudo podman build --rm --tag=jenkins_node_image --file=jenkins-auto.containerfile
    ```

9. Once complete, look at your image's information:

    ```bash
    sudo podman images
    ```

    **Output (other images may also appear):**

    ```bash
    REPOSITORY                    TAG         IMAGE ID      CREATED             SIZE
    localhost/jenkins_node_image  latest      73536a580d6f  About a minute ago  902 MB
    docker.io/library/almalinux   8           4e97feadb276  6 weeks ago         204 MB
    ...
    ```

    > **NOTE** - Any repositories named `<none>` that appear are intermediate images, used to build the final image. However, the `--rm` option should have told Podman to delete them after a successful build.

10. Using the new image, create an SVN node and attach it to the network:

     ```bash
     # Optional; stop and remove the node if it exists
     sudo podman stop jenkins_node
     sudo podman rm jenkins_node
     # Create the node and attach it to the network
     sudo podman run -dt --name jenkins_node --replace --restart=unless-stopped --net devnet --ip 192.168.168.20 --cap-add AUDIT_WRITE jenkins_node_image
     ```

11. Look at the containers:

     ```bash
     sudo podman ps --all
     ```

     **Output (other nodes may also appear):**

     ```bash
     CONTAINER ID  IMAGE                                COMMAND     CREATED             STATUS              PORTS       NAMES
     e01d98f007f5  localhost/jenkins_node_image:latest  /sbin/init  About a minute ago  Up About a minute               jenkins_node
     ...
     ```

12. Check the IPv4 addresses of the node; it should be `192.168.168.20`:

     ```bash
     sudo podman inspect jenkins_node -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
     ```

-----

## Access and Setup Jenkins

1. Open a Terminal, if one is not already open.

2. Open a browser and navigate to the IPv4 address of the Jenkins server:

    ```bash
    firefox 192.168.168.20:8080
    ```

3. The Jenkins Login page should appear:

    > **NOTE** - Unlike the Manual Setup, you will not have to unlock Jenkins, nor perform further initial setup tasks. The `init.groovy` script unlocked Jenkins, set the admin user's password, and installed the desired plugins.

    ![Jenkins Login Page](/03-jenkins-container/img/05a-jenkins-auto-login-page.png "Jenkins Login Page")

4. Enter ***"jenkinsuser"*** for the username and ***"Change.Me.123"*** for the password, then click on **Sign In**. The Jenkins Dashboard should appear:

    ![Jenkins Dashboard](/03-jenkins-container/img/11-jenkins-dashboard.png "Jenkins Dashboard")

5. Return to the [main section of this tutorial](/03-jenkins-container/03-jenkins-container.md) to continue.
