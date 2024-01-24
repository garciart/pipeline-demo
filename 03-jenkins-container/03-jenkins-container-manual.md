# Jenkins Container Demo (Manual Setup)

These instructions will create a Jenkins container that requires the normal initial setup (i.e., unlocking Jenkins, creating an admin user, installing plugins). However, unlike the [Automatic Setup](/03-jenkins-container/03-jenkins-container-auto.md), the containerfile will also enable an SSH service, which will allow you to manage the container using Ansible.

- [Create and Add the Jenkins Server Container to the Network](#create-and-add-the-jenkins-server-container-to-the-network)
- [Access and Setup Jenkins](#access-and-setup-jenkins)

> **WARNING** -  This is only a proof-of-concept demo for a single user! Do not use for production.

-----

## Create and Add the Jenkins Server Container to the Network

For this tutorial, you will use the freely available AlmaLinux 8 image as the operating system for your containers. However, you may use other comparable images, such as CentOS, Rocky Linux, or a Red Hat's Universal Base Image (UBI) (subscription required).

1. Open a Terminal, if one is not already open.

2. Create a containerfile:

    ```bash
    touch jenkins-manual.containerfile
    ```

3. Using an editor of your choice, open `jenkins-manual.containerfile` and add the following code:

    ```dockerfile
    # Pull a Docker or Podman image. For this demo, you will use AlmaLinux 8
    FROM almalinux:8

    # Ensure system is up-to-date
    RUN yum -y update &&\
        yum -y upgrade &&\
        yum -y clean all &&\
        yum -y autoremove

    # Ensure the passwd utility is installed
    RUN yum -y install passwd

    # Create a non-root user and create a root password
    # useradd  --comment "Default User Account" --create-home -groups wheel user
    RUN useradd -c "Default User Account" -m -G wheel user &&\
        echo Change.Me.123 | passwd user --stdin &&\
        echo Change.Me.321 | passwd root --stdin

    # Adapted from https://access.redhat.com/solutions/7015042
    # Install openssh and sudo
    RUN yum -y install openssh openssh-askpass openssh-clients openssh-server &&\
        yum -y install sudo
    
    # Enable the daemons
    RUN systemctl enable sshd

    # Customize the SSH daemon
    RUN mkdir --parents /var/run/sshd &&\
        ssh-keygen -A &&\
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak &&\
        sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config &&\
        cp /etc/pam.d/sshd /etc/pam.d/sshd.bak &&\
        sed -i 's@session\s*required\s*pam_loginuid.so@#session optional pam_loginuid.so@g' /etc/pam.d/sshd

    # Prevent 'System is booting up. Unprivileged users are not permitted to log in yet' error when not root
    # Do not exit on error if the directory does not exist: rm /run/nologin || true
    RUN rm /run/nologin || :

    # Pass environment variables 
    # https://stackoverflow.com/questions/36292317/why-set-visible-now-in-etc-profile
    ENV NOTVISIBLE "in users profile"
    RUN echo "export VISIBLE=now" >> /etc/profile

    # Install Java, fontconfig and Node.js (for SonarScanner)
    RUN yum -y install java-17-openjdk-devel fontconfig
    RUN yum -y install nodejs
    RUN npm cache clean -f &&\
        npm install -g n &&\
        n stable

    # Install the wget tool to fetch the Jenkins repository:
    RUN yum -y install wget

    # Get the Jenkins repo and key
    RUN wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo &&\
        rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key &&\
        yum makecache

    # Install Jenkins
    RUN yum -y install jenkins

    # Enable Jenkins as a service
    RUN systemctl enable jenkins

    # Install Python for Flask demo
    RUN yum -y install python39

    # Allow traffic through ports 22 (SSH) and 8080 (Jenkins)
    EXPOSE 22 8080

    # Ensure the system is still up-to-date
    RUN yum -y update

    # Start the systemd service
    # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman#starting_services_within_a_container_using_systemd
    CMD [ "/sbin/init" ]
    ```

4. Build the image:

    > **NOTE** - Podman uses `/var/tmp` by default to download and build images. If a `No space left on device` error appears during the build, you can change the `image_copy_tmp_dir` setting in the `containers.conf` file, usually located in `/usr/share/containers/containers.conf`.

    ```bash
    # Optional; remove final and intermediate images if they exist
    sudo podman rmi jenkins_node_image --force
    sudo podman image prune --all --force
    # Build the image
    sudo podman build --rm --tag=jenkins_node_image --file=jenkins-manual.containerfile
    ```

5. Once complete, look at your image's information:

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

6. Using the new image, create a Jenkins node and attach it to the network:

    ```bash
    # Optional; stop and remove the node if it exists
    sudo podman stop jenkins_node
    sudo podman rm jenkins_node
    # Create the node and attach it to the network
    sudo podman run -dt --name jenkins_node --replace --restart=unless-stopped --net devnet --ip 192.168.168.20 --cap-add AUDIT_WRITE jenkins_node_image
    ```

7. Look at the containers:

    ```bash
    sudo podman ps --all
    ```

    **Output (other nodes may also appear):**

    ```bash
    CONTAINER ID  IMAGE                                COMMAND     CREATED             STATUS              PORTS       NAMES
    e01d98f007f5  localhost/jenkins_node_image:latest  /sbin/init  About a minute ago  Up About a minute               jenkins_node
    ...
    ```

8. Check the IPv4 addresses of the node; it should be `192.168.168.20`:

    ```bash
    sudo podman inspect jenkins_node -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
    ```

    > **NOTE** - If you run into any issues, you can always access the container using one of the following commands:

    ```bash
    sudo podman exec -it jenkins_node /bin/bash

    -or-

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.168.20

    -or-

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null user@192.168.168.20
    ```

-----

## Access and Setup Jenkins

1. Open a Terminal, if one is not already open.

2. Open a browser and navigate to the IPv4 address of the Jenkins server:

    ```bash
    firefox 192.168.168.20:8080
    ```

3. A web page should appear, asking you to unlock Jenkins:

    ![Unlock Jenkins](/03-jenkins-container/img/05-jenkins-unlock.png "Unlock Jenkins")

4. In the Terminal, follow the instructions and look at the contents of `/var/lib/jenkins/secrets/initialAdminPassword`:

    - Using `podman exec`:

        ```bash
        sudo podman exec jenkins_node cat /var/lib/jenkins/secrets/initialAdminPassword
        ```

    - Using SSH as `root`; enter ***"Change.Me.321"*** when prompted for a password:

        ```bash
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.168.20
        java -jar /usr/share/java/jenkins.war --version
        cat /var/lib/jenkins/secrets/initialAdminPassword
        logout
        ```

5. Return to Jenkins and enter the password. A web page should appear, asking you to customize Jenkins:

    ![Customize Jenkins](/03-jenkins-container/img/06-jenkins-customize.png "Customize Jenkins")

6. Select **Install suggested plugins** for now. Jenkins will begin its setup process:

    ![Jenkins Plugin Setup](/03-jenkins-container/img/07-jenkins-plugin-setup.png "Jenkins Plugin Setup")

    > **NOTE** - If any plugins fail to install properly, retry. Sometimes, a plugin requires another plugin, causing a race condition, and a retry may fix the problem.

7. A web page should appear, asking you to create the first admin user:

    ![Jenkins First Admin](/03-jenkins-container/img/08-jenkins-first-admin.png "Jenkins First Admin")

8. Enter the following information:

    - Username: ***jenkinsuser***
    - Password: ***Change.Me.123***
    - Confirm password: ***Change.Me.123***
    - Full name: ***jenkinsuser***
    - E-mail address: <***Enter an email address***>

9. A web page should appear, asking you to verify the Jenkins URL:

    ![Jenkins Instance Configuration](/03-jenkins-container/img/09-jenkins-instance-configuration.png "Jenkins Instance Configuration")

10. Click on **Save and Finish**. A web page should appear, telling you that Jenkins is ready:

    ![Jenkins is Ready](/03-jenkins-container/img/10-jenkins-is-ready.png "Jenkins is Ready")

11. Click on **Start using Jenkins**. The Jenkins Dashboard should appear:

    ![Jenkins Dashboard](/03-jenkins-container/img/11-jenkins-dashboard.png "Jenkins Dashboard")

12. By default, Jenkins uses the Git version control system. To use Subversion with Jenkins, you must install the Subversion plugin. Click on **Manage Jenkins** or navigate to `http://192.168.168.20:8080/manage`. The Manage Jenkins page should appear:

    > **NOTE** - Ignore any errors or issues for now. Restarting Jenkins should fix these issues, which you will do shortly.

    ![Jenkins Manage Page](/03-jenkins-container/img/12-jenkins-manage-page.png "Jenkins Manage Page")

13. Click on **Plugins** or navigate to `http://192.168.168.20:8080/manage/pluginManager`. The Plugins page should appear:

    ![Jenkins Plugins Page](/03-jenkins-container/img/13-jenkins-plugins-page.png "Jenkins Plugins Page")

14. Click on **Available Plugins** or navigate to <http://192.168.168.20:8080/manage/pluginManager/available>. A list of available plugins should appear. Enter ***"subversion"*** in the search box; the **Subversion** plugin should appear at the top of the list. Check the **Install** box next to the plugin:

    ![Jenkins SVN Plugin Search Results](/03-jenkins-container/img/14-jenkins-svn-plugin-search-results.png "Jenkins SVN Plugin Search Results")

15. Click on **Download now and install after restart**. The Download progress page should appear:

    ![Jenkins Download Progress Page Top](/03-jenkins-container/img/15-jenkins-download-progress-page-top.png "Jenkins Download Progress Page Top")

16. Scroll to the bottom of the page:

    ![Jenkins Download Progress Page Bottom](/03-jenkins-container/img/16-jenkins-download-progress-page-bottom.png "Jenkins Download Progress Page Bottom")

17. Click on **Restart Jenkins when installation is complete and no jobs are running**. A web page should appear, asking you to please wait while Jenkins restarts:

    ![Jenkins Restart Page](/03-jenkins-container/img/17-jenkins-restart-page.png "Jenkins Restart Page")

18. After a few minutes, the Jenkins Login page should appear:

    ![Jenkins Login Page](/03-jenkins-container/img/18-jenkins-login-page.png "Jenkins Login Page")

19. Enter ***"jenkinsuser"*** for the username and ***"Change.Me.123"*** for the password, then click on **Sign In**. If the Download progress page reappears, click on **Go back to the top page** to return to the Dashboard:

    ![Jenkins Download Progress Page Blank](/03-jenkins-container/img/19-jenkins-download-progress-page-blank.png "Jenkins Download Progress Page Blank")

20. Return to the [main section of this tutorial](/03-jenkins-container/03-jenkins-container.md) to continue.
