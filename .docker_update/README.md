# Development Pipeline Demo

This repository contains my notes and instructions for creating a simple development pipeline using containers.

> **WARNING** - This is only a proof-of-concept demo for a single user; you should not use it for production.

- Create a Custom Image
- Create a Docker Network
- Add Subversion Container
- Add Jenkins Service
- Unit Test a Commit
- Check Code Quality Using SonarQube

Pull from repo
Test application:
- PyLint
- Unit Test
- SonarQube
- Selenium


-----

## Setup

If you have not already installed Docker, follow the instructions for your operating system at <https://docs.docker.com/engine/install/>.

> **NOTE** - Instead of Docker, Red Hat Enterprise Linux (RHEL) uses [Podman](https://podman.io/ "Podman"). Both Docker and Podman use a similar syntax. However, to use Docker on a RHEL system, you must install Podman first.
