# Jenkins Container Demo (Manual Setup)

In this tutorial, you will run a Jenkins automation server in a container, to manage continuous integration and continuous delivery (CI/CD) tasks.

- [Getting Started](#getting-started)
- [Create and Add the Jenkins Server Container to the Network](#create-and-add-the-jenkins-server-container-to-the-network)
- [Create a Pipeline](#create-a-pipeline)
- [Add a Jenkinsfile to the Repository](#add-a-jenkinsfile-to-the-repository)
- [Summary](#summary)

> **WARNING** -  This is only a proof-of-concept demo for a single user! Do not use for production.

-----

## Getting Started

Perform the following tasks from the [Podman Network Demo](/01-podman-network/01-podman-network.md).

- [Environment](/01-podman-network/01-podman-network.md#environment)
- [Start Podman](/01-podman-network/01-podman-network.md#start-podman)
- [Create the Network](/01-podman-network/01-podman-network.md#create-the-network)

-----

## Create and Add the Jenkins Server Container to the Network

For this tutorial, you will use the freely available AlmaLinux 8 image as the operating system for your containers. However, you may use other comparable images, such as CentOS, Rocky Linux, or a Red Hat's Universal Base Image (UBI) (subscription required).

You have two options:

- **[Manual Setup](/03-jenkins-container/03-jenkins-container-manual.md)**: These instructions will create a Jenkins container that requires the normal initial setup (i.e., unlocking Jenkins, creating an admin user, installing plugins). However, unlike the [Automatic Setup](/03-jenkins-container/03-jenkins-container-auto.md), the containerfile will also enable an SSH service, which will allow you to manage the container using Ansible.

- **[Automatic Setup](/03-jenkins-container/03-jenkins-container-auto.md)**: These instructions will create a Jenkins container that is unlocked, configured with an admin user, and with the recommended plugins (plus JUnit and Subversion) already installed; it will not require you to perform the normal initial setup process for Jemkins. However, unlike the [Manual Setup](/03-jenkins-container/03-jenkins-container-manual.md), the containerfile will **NOT** enable an SSH service that can be accessed using Ansible. You will still be able to execute `sudo podman exec jenkins_node` commands, though.

Once you have set up Jenkins, return here and continue the tutorial.

-----

## Create a Pipeline

1. At the Dashboard, click on **New Item** or navigate to `http://192.168.168.20:8080/view/all/newJob`. The Jenkins New Job page should appear. Enter ***"pipeline-demo"*** as the item name, select **Pipeline**, and click on **OK**:

    > **NOTE** - Ensure the SVN container you created in the [Subversion Container Demo](../02-svn-container/02-svn-container.md) is up and running first.

    ![Jenkins Demo Job](21-jenkins-demo-job.png "Jenkins Demo Job")

2. The Configuration page should appear:

    ![Jenkins Job Configuration Page](22-jenkins-job-configuration-page.png "Jenkins Job Configuration Page")

3. In the **General** section, enter ***"Pipeline Demo Job"*** in the **Description** textbox.

4. Scroll down to the **Build Triggers** section and select **Poll SCM**. A new set of options should appear:

    - **Schedule**: Enter *** "H/2 * * * * " *** (this will poll the SVN server every two minutes).

5. Scroll down to the **Pipeline** section and enter the following script:

    ```
    pipeline {
        agent any

        stages {
            stage('Hello') {
                steps {
                    echo 'Hello World'
                }
            }
        }
    }
    ```

6. Click on **Save** when finished. The pipeline-demo job page should appear:

    ![Jenkins Pipeline Job Page](23-jenkins-pipeline-job-page.png "Jenkins Pipeline Job Page")

7. Wait two minutes, then refresh the page. The initial build should appear under **Build History**, along with the **Stage View***:

    > **NOTE** - No other builds will appear until there is a change in the repository or configuration.

    ![Jenkins Initial Build](24-jenkins-initial-build.png "Jenkins Initial Build")

8. Click on the build (**#1**) under **Build History**. The build page should appear:

    ![Jenkins Build Page 1](25-jenkins-build-page-1.png "Jenkins Build Page 1")

9. On the **Build** page, click on the **Console Output** link. Look through the output, and you will see "Hello, World!":

    ![Jenkins Console Output 1](26-jenkins-console-output-1.png "Jenkins Console Output 1")

11. Click on the **pipeline-demo** link at the top of the page to return to the project page.

-----

## Add a Jenkinsfile to the Repository

> **NOTE** - Ensure you have installed Subversion on the development host: `sudo yum -y install subversion`

1. Open a Terminal, if one is not already open.

2. Checkout the repository:

    ```
    svn checkout http://192.168.168.10/svn/demorepo/
    ```

3. If prompted for your sudo credentials, enter your password:

    ```
    Authentication realm: <http://192.168.168.10:80> SVN Repository
    Password for '<your username>': *************
    ```

4. When prompted for the repository credentials, enter ***"svnuser"*** for the username and ***"Change.Me.123"*** for the password:

    ```
    Authentication realm: <http://192.168.168.10:80> SVN Repository
    Username: svnuser
    Password for 'svnuser': *************
    ```

5. Navigate to the repository directory:

    ```
    cd demorepo
    ```

6.  Ensure your local repository is up-to-date with the remote repository. When prompted for the repository password, enter ***"Change.Me.123"***:

    ```
    svn update
    ```

7. Create a Jenkinsfile:

    ```
    touch Jenkinsfile
    ```

8. Using an editor of your choice, open the Jenkinsfile and add the following code:

    ```
    pipeline {
        agent any

        stages {
            stage('Build') {
                steps {
                    echo "Building ${env.JOB_NAME}..."
                }
            }
            stage('Test') {
                steps {
                    echo "Testing ${env.JOB_NAME}..."
                }
            }
            stage('Deploy') {
                steps {
                    echo "Deploying ${env.JOB_NAME}..."
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

9. Add the Jenkinsfile to your local repository:

    ```
    svn add . --force
    ```

10. Push your changes to the remote repository. When prompted for the repository password, enter ***"Change.Me.123"***:

    ```
    svn commit -m "Added Jenkinsfile."
    ```

11. If it is not already open, access Jenkins in the browser and open the **pipline-demo** project:

    ![Jenkins Dashboard with Project](27-jenkins-dashboard-with-project.png "Jenkins Dashboard with Project")

12. Click on **Configure**.

13. Scroll down to the **Pipeline** section and select **Pipeline script from SCM** from the **Definition** dropdown list. This will allow you to run custom build, using a Jenkinsfile stored in your repository.

14. Select **Subversion** from the **SCM** dropdown list. A new set of options should appear:

    - **Repository URL**: Enter ***"http://192.168.168.10/svn/demorepo"***.
    - **Credentials**:
        - Click **Add**, then click on the **Jenkins Credentials Provider** button.
        - When the Jenkins Credentials Provider screen appears, enter ***"svnuser"*** for the username and ***"Change.Me.123"*** for the password, then click on **Add**.

            ![Jenkins Credentials Provider](28-jenkins-credentials-provider.png "Jenkins Credentials Provider")

        - Go back to the **Credentials** dropdown list and select the **svnuser**.

15. Scroll down and uncheck the **Lightweight checkout** checkbox.

8. Click on **Save** when finished. The pipeline-demo job page should reappear:

    ![Jenkins Pipeline Job Page](24-jenkins-initial-build.png "Jenkins Pipeline Job Page")

9. Wait two minutes for Jenkins to contact the SVN server, then refresh the page. Another build should appear under **Build History**, along with the **Stage View***:

    > **NOTE** - If refresh does not work, click on **Build Now**.

    ![Jenkins Jenkinsfile Build](29-jenkins-jenkinsfile-build.png "Jenkins Jenkinsfile Build")

12. Now that there is a Jenkinsfile in the repository, Jenkins will run it every time there is a change in the repository. You can use the Jenkinsfile to run tests, scans, and to deploy code to a server.

    > **NOTE** - If you want to rerun the Jenkinsfile, simply click **Build Now**.
    
13. Click on the build (**#2**) under **Build History**. The build page should appear:

    ![Jenkins Build Page 2](30-jenkins-build-page-2.png "Jenkins Build Page 2")

14. On the **Build** page, click on the **Console Output** link. Look through the output, and you will see comments for each stage, as well as the success message of "Good to go!":

    ![Jenkins Console Output 2](31-jenkins-console-output-2.png "Jenkins Console Output 2")

16. Click on the **pipeline-demo** link at the top of the page to return to the project page.

-----

## Summary

In this tutorial, you ran a Jenkins automation server in a container, pulling code from a Subversion server and running a build using a Jenkinsfile. Remember, this is only a proof-of-concept demo for a single user; you should not use it for production.