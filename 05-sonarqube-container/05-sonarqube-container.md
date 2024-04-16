# SonarQube Container Demo

In this tutorial, you will create a SonarQube container and integrate it into a Jenkins pipeline, allowing you to check code quality each time a change is pushed to the repository.

- [Getting Started](#getting-started)
- [Create and Add the SonarQube Server Container to the Network](#create-and-add-the-sonarqube-server-container-to-the-network)
- [Access and Setup SonarQube](#access-and-setup-sonarqube)
- [Summary](#summary)

> **WARNING** -  This is only a proof-of-concept demo for a single user! Do not use for production.

-----

## Getting Started

1. Ensure you have completed the steps in the [Pipeline Testing Stage Demo](/04-testing-stage/04-testing-stage.md).

2. Ensure that the following containers are running:

    - Subversion: `sudo podman start svn_node`
    - Jenkins: `sudo podman start jenkins_node`

3. Ensure that the **svn-root** volume exists: `sudo podman volume inspect svn-root`

4. Ensure you are not in the `demorepo` directory (your local repository) yet; otherwise, you may push files to the repository that should not be there, such as containerfiles.

-----

## Create and Add the SonarQube Server Container to the Network

For this tutorial, you will use the freely available AlmaLinux 8 image as the operating system for your containers. However, you may use other comparable images, such as CentOS, Rocky Linux, or a Red Hat's Universal Base Image (UBI) (subscription required).

1. Open a Terminal, if one is not already open.

2. SonarQube uses the Elasticsearch search engine, and Elasticsearch uses a `mmapfs` directory to store its indices. On most systems, the default mmap count limit is 65530, which is too low for Elasticsearch, resulting in out-of-memory exceptions. In order for SonarQube to work, [you must set the `vm.max_map_count` on the ***container's host*** to a minimum value of 262144](https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html):

    ```bash
    sudo dnf -y install procps-ng
    sudo echo "vm.max_map_count=262144" /etc/sysctl.d/99-sysctl.conf
    sudo sysctl -w vm.max_map_count=262144
    ```

    > **NOTE** - You could run this command in the container itself, but it would return to the default value, set in the container's host, each time the container was restarted.

3. Create a service file:

    ```bash
    touch sonarqube.service
    ```

4. Using an editor of your choice, open `sonarqube.service` and add the following code:

    ```ini
    [Unit]
    Description=SonarQube service
    After=syslog.target network.target

    [Service]
    Type=simple
    User=sonaruser
    Group=sonaruser
    PermissionsStartOnly=true
    ExecStart=/bin/nohup /usr/bin/java -Xms32m -Xmx32m -Djava.net.preferIPv4Stack=true -jar /opt/sonarqube/lib/sonar-application-10.0.0.68432.jar
    StandardOutput=syslog
    LimitNOFILE=65536
    LimitNPROC=8192
    TimeoutStartSec=5
    Restart=always
    SuccessExitStatus=143

    [Install]
    WantedBy=multi-user.target
    ```

5. Create a containerfile:

    ```bash
    touch sonarqube.containerfile
    ```

6. Using an editor of your choice, open `sonarqube.containerfile` and add the following code:

    ```dockerfile
    # Pull a Docker or Podman image. For this demo, you will use AlmaLinux 8
    FROM almalinux:8
    USER root

    # Ensure the system is up-to-date
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
    # Install openssh, httpd, and sudo
    RUN yum -y install openssh openssh-askpass openssh-clients openssh-server &&\
        yum -y install httpd &&\
        yum -y install sudo

    # Enable the HTTP and SSH daemons
    RUN systemctl enable httpd &&\
        systemctl enable sshd

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

    # Install Java
    RUN yum -y install java-17-openjdk-devel

    # Ensure wget and unzip are installed
    RUN yum -y install wget && yum -y install unzip

    # Download and extract SonarQube
    RUN mkdir --parents /opt
    RUN wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.0.0.68432.zip
    RUN unzip sonarqube-10.0.0.68432.zip -d /opt
    RUN mv /opt/sonarqube-10.0.0.68432 /opt/sonarqube
    RUN rm -f sonarqube-10.0.0.68432.zip

    RUN wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
    RUN unzip sonar-scanner-cli-5.0.1.3006-linux.zip -d /opt
    # FYI: Unzip changes the name (removing the -cli part)
    RUN mv /opt/sonar-scanner-5.0.1.3006-linux /opt/sonar-scanner
    RUN rm -f sonar-scanner-cli-5.0.1.3006-linux.zip
    RUN export PATH=/opt/sonar-scanner/bin:$PATH

    # Create a SonarQube user
    # id -u sonaruser &>/dev/null || useradd --home-dir /opt/sonarqube/ --groups wheel --system sonaruser
    RUN useradd -c "SonarQube Account" -d /opt/sonarqube/ -G wheel -r sonaruser &&\
        echo Change.Me.123 | passwd sonaruser --stdin &&\
        chown -R sonaruser:sonaruser /opt/sonarqube &&\
        chmod 775 -R /opt/sonarqube

    RUN chown -R sonaruser:sonaruser /opt/sonar-scanner &&\
        chmod 775 -R /opt/sonar-scanner

    # Create the SonarQube service
    ADD sonarqube.service /etc/systemd/system/sonarqube.service

    # Start SonarQube
    RUN systemctl enable sonarqube
    RUN runuser --login sonaruser --command "/opt/sonarqube/bin/linux-x86-64/sonar.sh start"

    # Allow traffic through ports 22 (SSH) and 9000 (SonarQube)
    EXPOSE 22 9000

    # Ensure the system is still up-to-date
    RUN yum -y update

    # Start the systemd service
    # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman#starting_services_within_a_container_using_systemd
    CMD [ "/sbin/init" ]
    ```

7. Build the image:

    > **NOTE** - Podman uses `/var/tmp` by default to download and build images. If a `No space left on device` error appears during the build, you can change the `image_copy_tmp_dir` setting in the `containers.conf` file, usually located in `/usr/share/containers/containers.conf`.

    ```bash
    # Optional; remove final and intermediate images if they exist
    sudo podman rmi sonarqube_node_image --force
    sudo podman image prune --all --force
    # Build the image
    sudo podman build --rm --tag=sonarqube_node_image --file=sonarqube.containerfile
    ```

8. Once complete, look at your image's information:

    ```bash
    sudo podman images
    ```

    **Output (other images may also appear):**

    ```bash
    REPOSITORY                      TAG         IMAGE ID      CREATED             SIZE
    localhost/sonarqube_node_image  latest      931be7a02def  46 seconds ago  2.78 GB
    docker.io/library/almalinux     8           4e97feadb276  6 weeks ago         204 MB
    ...
    ```

    > **NOTE** - Any repositories named `<none>` that appear are intermediate images, used to build the final image. However, the `--rm` option should have told Podman to delete them after a successful build.

9. Using the new image, create a SonarQube node and attach it to the network:

    ```bash
    # Optional; stop and remove the nodes if they exist
    sudo podman stop sonarqube_node
    sudo podman rm sonarqube_node
    # Create the nodes and attach them to the network
    sudo podman run -dt --name sonarqube_node --replace --restart=unless-stopped --net devnet --ip 192.168.168.30 --cap-add AUDIT_WRITE sonarqube_node_image
    ```

10. Look at the containers:

    ```bash
    sudo podman ps --all
    ```

    **Output (other nodes may also appear):**

    ```bash
    CONTAINER ID  IMAGE                                  COMMAND     CREATED         STATUS         PORTS  NAMES
    048eb28a2192  localhost/sonarqube_node_image:latest  /sbin/init  15 seconds ago  Up 15 seconds         sonarqube_node
    ...
    ```

11. Check the IPv4 addresses of the node; it should be `192.168.168.30`:

    ```bash
    sudo podman inspect sonarqube_node -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
    ```

    > **NOTE** - If you run into any issues, you can always access the container using one of the following commands:

    ```bash
    sudo podman exec -it sonarqube_node /bin/bash

    -or-

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.168.30

    -or-

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null user@192.168.168.30
    ```

-----

## Access and Setup SonarQube

1. Open a Terminal, if one is not already open.

2. Open a browser and navigate to the IPv4 address of the SonarQube server:

    ```bash
    firefox 192.168.168.30:9000
    ```

3. A web page should appear, asking you to log in:

    ![Log in to SonarQube](/05-sonarqube-container/img/37-log-in-into-sonarqube.png "Log in to SonarQube")

4. Enter ***"admin"*** for both the username and the password. A new page will appear, asking you to change your password. Change it to ***"Change.Me.123"*** for now:

    ![Update your password](/05-sonarqube-container/img/38-update-your-password.png "Update your password")

5. A page will appear, asking you how do you want to create your project:

    ![How do you want to create your project?](/05-sonarqube-container/img/39-how-do-you-want-to-create-your-project.png "How do you want to create your project?")

    > **NOTE** - A warning appears at the bottom of the page, stating that, *"The embedded database should be used for evaluation purposes only."* By default, SonarQube uses a built-in H2 database. You can change the database to [a supported database, such as PostgreSQL, MS SQL Server, and Oracle/MySQL](https://docs.sonarsource.com/sonarqube/9.9/setup-and-upgrade/install-the-server/) if you like, but that is beyond the scope of this tutorial. Please note that the Community Edition does not support running SonarQube in a clustered configuration.

6. Unfortunately, Subversion is not a supported DevOps platform. Click on **Manually** and the **Create a project** page should appear. Enter the following values, and then click on **Setup**:

    - **Project display name**: pipeline-demo
    - **Project key**: pipeline-demo
    - **Main branch name**: main

    ![Create a project](/05-sonarqube-container/img/40-create-a-project.png "Create a project")

7. A new page should appear, asking how do you want to analyze your repository. Even though you are going to use Jenkins, SonarQube with Jenkins does not support Subversion as a DevOps platform, so click on **Locally**:

    ![How do you want to analyze your repository?](/05-sonarqube-container/img/41-how-do-you-want-to-analyze-your-repository.png "How do you want to analyze your repository?")

8. The **Analyze your project** page should appear:

    ![Analyze your project](/05-sonarqube-container/img/42-analyze-your-project.png "Analyze your project")

9. Leave the values as-is for now and click on **Generate**. A token should appear; make sure you record it somewhere, since you will need it later. Click on **Continue** when done:

    ![Provide a token](/05-sonarqube-container/img/43-provide-a-token.png "Provide a token")

10. When the **Run analysis on your project** page appears, click on **Other (for JS, TS, Go, Python, PHP, ...)**

    ![Run analysis on your project](/05-sonarqube-container/img/44-run-analysis-on-your-project.png "Run analysis on your project")

11. When asked for your operating system, select **Linux**:

    ![What is your OS?](/05-sonarqube-container/img/45-what-is-your-os.png "What is your OS?")

12. A set of instructions will appear, explaining how to leverage SonarScanner to send its results to the SonarQube server. Click **Copy** and record the instructions:

    ![Execute the Scanner](/05-sonarqube-container/img/46-execute-the-scanner.png "Execute the Scanner")

13. The good news is that you installed SonarScanner when you created the Subversion container, using the containerfile. Right now, if your Jenkins container is not open in a browser, open a Terminal (if one is not open), and access your Jenkins container:

    ```bash
    firefox 192.168.168.20:8080
    ```

14. If you are not logged in, log in, entering ***"jenkinsuser"*** for the username and ***"Change.Me.123"*** for the password. Click on **Dashboard** -> **Manage Jenkins** -> **Plugins**. Click on **Available plugins**, and, in the text box, enter ***"sonarqube"***:

    ![Available plugins](/05-sonarqube-container/img/47-available-plugins.png "Available plugins")

15. Select **SonarQube Scanner** and click on **Download now and install after restart**. The **Download progress** page should appear:

    ![Download progress](/05-sonarqube-container/img/48-download-progress.png "Download progress")

16. Check the **Restart Jenkins when installation is complete and no jobs are running** box. When Jenkins restarts, log back in, and click on **Dashboard** -> **Manage Jenkins**:

    ![Manage Jenkins](/05-sonarqube-container/img/49-manage-jenkins.png "Manage Jenkins")

17. Click on **System** to open the System page. Scroll down to **SonarQube servers** and click on **Add SonarQube**:

    ![SonarQube servers](/05-sonarqube-container/img/50-sonarqube-servers.png "SonarQube servers")

18. Enter the following information:

    - **Name**: DemoRepoSonarQubeServer
    - **Server URL**: <http://192.168.168.30:9000>
    - **Server authentication token**:
        - Click **Add**, then click on the **Jenkins Credentials Provider** button.
        - When the Jenkins Credentials Provider screen appears, change the kind to **Secret Text**, enter your token in the **Secret** textbox:
        - Enter ***"DemoRepoSonarQubeToken"*** in the **Description** textbox, then click on **Add**

            ![Jenkins Credentials Provider for SonarQube](/05-sonarqube-container/img/51-jenkins-credentials-provider-for-sonarqube.png "Jenkins Credentials Provider for SonarQube")

        - Go back to the **Server authentication token** dropdown list and select the **DemoRepoSonarQubeToken**.

19. Click on **Save** when finished to return to the Dashboard.

20. Click on **Manage Jenkins**, then click on **Tools**. Scroll down to **SonarQube Scanner** and click on **Add SonarQube Scanner**:

    ![SonarQube Scanner](/05-sonarqube-container/img/52-sonarqube-scanner.png "SonarQube scanner")

21. For **Name**, enter ***"DemoRepoSonarQubeScanner"***. Leave the default **Install from Maven Central** option as-is, but record the version number (i.e., SonarQube Scanner 5.0.1.3006); you will need it later. Click **Save** when done.

22. Go to your local `demorepo` repository and activate the virtual environment:

    ```bash
    source bin/activate
    ```

23. Using an editor of your choice, open the Jenkinsfile in your local `demorepo` repository. Add a ***"SonarQube Analysis"*** stage after the test stage, using the code snippet provided by SonarQube earlier, along with your Subversion credentials:

    > **NOTE** - Ensure you use the SHA256 hash your development machine created for data.csv, if it is different from the value in the test stage.

    ```groovy
    pipeline {
        agent {
            any {
                image 'python:3'
            }
        }
        stages {
            stage('build') {
                steps {
                    echo "Building ${env.JOB_NAME}..."
                    sh 'python3 -m pip install -r requirements.txt'
                    sh 'cat /etc/os-release'
                }
            }
            stage('test') {
                steps {
                    echo "Testing ${env.JOB_NAME}..."
                    // Ensure the data.csv file is not corrupted
                    sh 'echo "bc1932ebf66ff108fb5ff0a6769f2023a9002c7dafee53d85f14c63cab428b4a  data.csv" | sha256sum -c'
                    // Unit test app.py
                    sh 'python3 test_app.py'
                }
                post {
                    always {
                        junit 'test-reports/*.xml'
                    }
                }
            }
            stage('SonarQube Analysis') {
                environment {
                    SCANNER_HOME = tool 'DemoRepoSonarQubeScanner'
                    PROJECT_NAME = "pipeline-demo"
                }
                steps {
                    // Exclude the test-reports directory
                    withSonarQubeEnv('DemoRepoSonarQubeServer') {
                        sh '''$SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=pipeline-demo \
                        -Dsonar.sources=. \
                        -Dsonar.exclusions=test-reports/**/*.* \
                        -Dsonar.host.url=http://192.168.168.30:9000 \
                        -Dsonar.token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
                        -Dsonar.scm.provider=svn \
                        -Dsonar.svn.username=svnuser \
                        -Dsonar.svn.password.secured=Change.Me.123'''
                    }
                }
            }
        }
        post {
            success {
                echo "Good to go!"
            }
            failure {
                echo "Houston, we've had a problem."
            }
        }
    }
    ```

24. Push your changes to the remote repository. If prompted for the repository password, enter ***"Change.Me.123"***:

    ```bash
    svn add Jenkinsfile --force
    svn commit -m "Added SonarQube analysis stage." --non-interactive --username 'svnuser' --password 'Change.Me.123'
    ```

25. Deactivate your virtual environment:

    ```bash
    deactivate
    ```

26. Go back to Jenkins, wait two minutes for Jenkins to contact the SVN server, then refresh the page. Another build should appear under **Build History**, along with the **Stage View**.

    > **NOTE** - If refresh does not work, click on **Build Now**.

27. Click on the build (**#4**) under **Build History**. The build page should appear:

    ![Jenkins Build Page 4](/05-sonarqube-container/img/53-jenkins-build-page-4.png "Jenkins Build Page 4")

28. On the **Build** page, click on the **Console Output** link. Look through the output until you come across a line that looks similar to "`INFO: ANALYSIS SUCCESSFUL, you can find the results at: http://192.168.168.30:9000/dashboard?id=pipeline-demo`":

    ![Jenkins Console Output 4](/05-sonarqube-container/img/54-jenkins-console-output-4.png "Jenkins Console Output 4")

29. If you click on the link (or open it in a new tab), the results of your scan will appear:

    ![SonarQube Results 1](/05-sonarqube-container/img/55-sonarqube-results-1.png "SonarQube Results 1")

-----

## Summary

In this tutorial, you created a SonarQube container and integrated it into a Jenkins pipeline, allowing you to check code quality each time a change is pushed to the repository. Please continue to our [Deployment Stage Demo](/06-deployment-stage/06-deployment-stage.md). Remember, this is only a proof-of-concept demo for a single user; you should not use it for production.
