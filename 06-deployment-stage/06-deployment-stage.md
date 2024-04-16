# Deployment Stage Demo

In this tutorial, you will deploy your web application to a managed node after successfully building and testing it using Jenkins.

- [Getting Started](#getting-started)
- [Deploying the Application to a Container](#deploying-the-application-to-a-container)
- [Summary](#summary)

> **WARNING** -  This is only a proof-of-concept demo for a single user! Do not use for production.

-----

## Getting Started

1. Ensure you have completed the steps in the [SonarQube Container Demo](/05-sonarqube-container/05-sonarqube-container.md).

2. Ensure that the following containers are running:

    - Managed Node 1: `sudo podman start managed_node1`
    - Subversion: `sudo podman start svn_node`
    - Jenkins: `sudo podman start jenkins_node`
    - SonarQube: `sudo podman start sonarqube_node`

3. Ensure that the **svn-root** volume exists: `sudo podman volume inspect svn-root`

4. Ensure you are not in the `demorepo` directory (your local repository) yet; otherwise, you may push files to the repository that should not be there, such as containerfiles.

-----

## Deploying the Application to a Container

-----

## Summary

In this tutorial, you deployed your web application to a managed node after successfully building and testing it using Jenkins. Remember, this is only a proof-of-concept demo for a single user; you should not use it for production.
