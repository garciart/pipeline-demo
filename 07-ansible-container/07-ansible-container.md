# Ansible Container Demo

In this tutorial, you will ...

- [Getting Started](#getting-started)
- [Create and Add the Ansible Container to the Network](#create-and-add-the-ansible-container-to-the-network)
- [Access and Setup Ansible](#access-and-setup-ansible)
- [Summary](#summary)

> **WARNING** -  This is only a proof-of-concept demo for a single user! Do not use for production.

-----

## Getting Started

1. Ensure you have completed the steps in the [SonarQube Container Demo](/05-sonarqube-container/05-sonarqube-container.md).

2. Ensure that the following containers are running:

    - Subversion: `sudo podman start svn_node`
    - Jenkins: `sudo podman start jenkins_node`
    - SonarQube: `sudo podman start sonarqube_node`

3. Ensure that the **svn-root** volume exists: `sudo podman volume inspect svn-root`

-----

## Adding a Quality Gate

Security Hotspots are security-sensitive code that requires manual review to assess whether or not a vulnerability exists.

-----

## Summary

In this tutorial, you ... Remember, this is only a proof-of-concept demo for a single user; you should not use it for production.
