# Podman Network Demo

In this demo, you will create a simple network of containers. Each container will run two services: HTTP, to deliver web content to clients; and SSH, to allow remote access for administrators using tools like Ansible and PuTTY.

- [Environment](#environment)
- [Start Podman and Create the Network](#start-podman-and-create-the-network)
- [Create the Containers](#create-the-containers)
- [Add the Containers to the Network](#add-the-containers-to-the-network)
- [Access the Containers using HTTP](#access-the-containers-using-http)
- [Access the Containers through SSH](#access-the-containers-through-ssh)
- [Stop and Start the Containers](#stop-and-start-the-containers)
- [Clean Up (Optional)](#clean-up-optional)
- [Extra Credit](#extra-credit)
- [Summary](#summary)

> **WARNING** - This is only a proof-of-concept demo. Do not use for production.

-----

## Environment

- A development host, running a Fedora distribution later than 28 (e.g., Red Hat Linux 8, etc.), with:
  - The latest version of Podman compatible with your system
  - Python 3.9 or later
- If you are using Red Hat, you will need a subscription to Red Hat to update your system and access packages. Red Hat offers a free [Red Hat Developer Subscription for Individuals](https://developers.redhat.com/).
- The OpenSSH client, if it is not already installed. To install OpenSSH client, open a Terminal and enter the following command: `sudo yum -y install openssh openssh-clients`.
- You will also need the `sshpass` utility and the Ansible automation suite. To install them, open a Terminal and enter the following command: `python3 -m pip install sshpass ansible`.
- A desktop environment (e.g., GNOME, KDE, etc.) with a web browser (e.g., Mozilla Firefox, Google Chrome, etc.) is optional, but that will let you view the web pages you pushed to the server.

Podman supports ["rootful" (system) and "rootless" (user) modes](https://developers.redhat.com/blog/2020/09/25/rootless-containers-with-podman-the-basics), but, for this demo, you will use "rootful" containers to allow the development host to communicate with its containers using Secure Shell (SSH).

-----

## Start Podman and Create the Network

For this demo, you will create a simple bridge network to allow your containers to communicate with your host and the Internet.

1. Open a shell or Terminal application on your host.
2. Create a project directory in your home directory and navigate to it:

    ```{.text .cmd_input}
    cd ~/
    mkdir ~/podman_demo
    cd ~/podman_demo
    ```

3. Start the Podman service:

    ```bash
    sudo systemctl start podman
    sudo systemctl status podman | head
    ```

    > **NOTE** - You can enable the podman service to automatically start when your host boots up:
    >
    > ```bash
    > sudo systemctl enable podman
    > ```

4. Create a container network named ***"devnet"***:

    ```bash
    # Optional / Remove any old networks first
    sudo podman network rm --force devnet
    
    # Create the container network
    sudo podman network create --driver bridge --subnet 192.168.168.0/24 --gateway 192.168.168.1 devnet
    ```

    > **NOTE** - You can find documentation of Podman commands at <https://docs.podman.io/en/latest/index.html>.

5. Check your work:

    ```bash
    sudo podman network ls | grep devnet && sudo podman inspect devnet
    ```

    *(Sample output; your results may differ:)*

    ```text
    abcdef012345  devnet      bridge
    [
         {
              "name": "devnet",
              "id": "abcdef01234567899876543210fedcbaabcdef01234567899876543210fedcba",
              "driver": "bridge",
              "network_interface": "cni-podman1",
              "created": "2023-07-01T13:26:00.733731157-04:00",
              "subnets": [
                   {
                        "subnet": "192.168.168.0/24",
                        "gateway": "192.168.168.1"
                   }
              ],
              "ipv6_enabled": false,
              "internal": false,
              "dns_enabled": false,
              "ipam_options": {
                   "driver": "host-local"
              }
         }
    ]
    ```

-----

## Create the Containers

1. Using an editor of your choice, create a file named `demo.containerfile` in your project directory with the following code:

    ```text
    # Pull a Docker or Podman image.
    FROM registry.access.redhat.com/ubi8

    # Ensure the system is up-to-date
    RUN yum -y update

    # Ensure the passwd utility is installed
    RUN yum -y install passwd

    # Create a non-root user and create a root password
    # useradd --comment "Default User Account" --create-home --groups wheel alice
    RUN useradd -c "Default User Account" -m -G wheel alice &&\
        echo Change.Me.123 | passwd alice --stdin &&\
        echo Change.Me.321 | passwd root --stdin

    # Adapted from https://access.redhat.com/solutions/7015042
    # Install openssh, httpd, iputils, and sudo
    RUN yum -y install openssh openssh-clients openssh-server &&\
        yum -y install httpd &&\
        yum -y install iputils &&\
        yum -y install sudo

    # Enable the HTTP and SSH daemons
    RUN systemctl enable httpd &&\
        systemctl enable sshd

    # Generate keys and backup the SSH daemon config
    RUN mkdir --parents /var/run/sshd &&\
        ssh-keygen -A &&\
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak &&\
        cp /etc/pam.d/sshd /etc/pam.d/sshd.bak

    # To get SSH login; must exec container with --cap-add AUDIT_WRITE
    # https://stackoverflow.com/questions/21391142/why-is-it-needed-to-set-pam-loginuid-to-its-optional-value-with-docker
    RUN sed -i 's@session\s*required\s*pam_loginuid.so@#session optional pam_loginuid.so@g' /etc/pam.d/sshd

    # Prevent 'System is booting up. Unprivileged users are not permitted to log in yet' error when not root
    # Do not exit on error if the directory does not exist: rm /run/nologin || true
    RUN rm /run/nologin || :

    # Pass environment variables 
    # https://stackoverflow.com/questions/36292317/why-set-visible-now-in-etc-profile
    ENV NOTVISIBLE "in users profile"
    RUN echo "export VISIBLE=now" >> /etc/profile

    # Set ownership of /var/www/html to apache to give alice access
    # Get the Apache user name in the container using 'apachectl -S' if this does not work
    RUN chown --recursive apache:apache /var/www/html &&\
        chmod -R 775 /var/www/html &&\
        usermod --append --groups apache alice


    # Allow traffic through ports 22 (SSH) and 80 (HTTP)
    EXPOSE 22 80

    # Ensure the system is still up-to-date
    RUN yum -y update &&\
        yum -y clean all
   
    # Start the systemd service
    # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman#starting_services_within_a_container_using_systemd
    CMD [ "/sbin/init" ]
    ```

2. Build the image:

    > **NOTE** - Podman uses `/var/tmp` by default to download and build images. If a `No space left on device` error appears during the build, you can change the `image_copy_tmp_dir` setting in the `containers.conf` file, usually located in `/usr/share/containers/containers.conf`.

    ```bash
    # Optional / Remove any old, unused, or intermediate images
    sudo podman rmi demo_image --force
    sudo podman image prune --all --force

    # Build the image
    sudo podman build --rm --tag=demo_image --file=demo.containerfile
    ```

3. Once complete, look at your image's information:

    ```bash
    sudo podman images
    ```

    *(Sample output; other images may exist:)*

    ```text
    REPOSITORY                       TAG         IMAGE ID      CREATED         SIZE
    localhost/demo_image             latest      a1b2c3d4e5f6  12 seconds ago  261 MB
    registry.access.redhat.com/ubi8  latest      bc1c6b923245  6 days ago      213 MB
    ...
    ```

    > **NOTE** - Any repositories named `<none>` that appear are intermediate images, used to build the final image. However, the `--rm` option should have told Podman to delete them after a successful build.

-----

## Add the Containers to the Network

1. Using the new image, create two demo nodes and attach them to the network:

    ```bash
    # Optional / Stop and remove old nodes
    sudo podman stop demo_node1
    sudo podman rm demo_node1
    sudo podman stop demo_node2
    sudo podman rm demo_node2

    # Create the nodes and attach them to the network
    # Add the AUDIT_WRITE capability to prevent 'connection closed by remote host' when using SSH
    sudo podman run --cap-add AUDIT_WRITE --detach --tty --name=demo_node1 --replace --restart=unless-stopped --network=devnet --ip=192.168.168.101 demo_image
    sudo podman run --cap-add AUDIT_WRITE -dt --name demo_node2 --replace --restart=unless-stopped --net devnet --ip 192.168.168.102 demo_image
    ```

2. Look at the containers:

    ```bash
    sudo podman ps --all
    ```

    *(Sample output; other nodes may exist:)*

    ```text
    CONTAINER ID  IMAGE                        COMMAND     CREATED         STATUS         PORTS       NAMES
    fedcba012345  localhost/demo_image:latest  /sbin/init  53 seconds ago  Up 53 seconds              demo_node1
    f1e2d3c4b5a6  localhost/demo_image:latest  /sbin/init  11 seconds ago  Up 11 seconds              demo_node2
    ...
    ```

3. Check the IPv4 addresses of the nodes; they should be `192.168.168.101` and `192.168.168.102`,
   respectively:

    ```bash
    sudo podman inspect demo_node1 -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
    sudo podman inspect demo_node2 -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
    ```

4. Ping the nodes from the development host:

    ```bash
    ping -c 2 192.168.168.101
    ping -c 2 192.168.168.102
    ```

    *(Sample output; your times may differ:)*

    ```text
    PING 192.168.168.101 (192.168.168.101) 56(84) bytes of data.
    64 bytes from 192.168.168.101: icmp_seq=1 ttl=64 time=0.096 ms
    64 bytes from 192.168.168.101: icmp_seq=2 ttl=64 time=0.111 ms

    --- 192.168.168.101 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1037ms
    rtt min/avg/max/mdev = 0.096/0.103/0.111/0.007 ms
    PING 192.168.168.102 (192.168.168.102) 56(84) bytes of data.
    64 bytes from 192.168.168.102: icmp_seq=1 ttl=64 time=0.113 ms
    64 bytes from 192.168.168.102: icmp_seq=2 ttl=64 time=0.115 ms

    --- 192.168.168.102 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1021ms
    rtt min/avg/max/mdev = 0.113/0.114/0.115/0.001 ms
    ```

5. Access the first container using Podman:

    > **NOTE** - Since you are running a process in the container other than a runtime shim, you cannot use `sudo podman attach demo_node1`.

    ```bash
    sudo podman exec --interactive --tty demo_node1 /bin/bash
    ```

    *(Sample output; your container ID may differ:)*

    ```bash
    [root@fedcba012345 /]#
    ```

6. Ping the second container from demo_node1:

    ```bash
    ping -c 2 192.168.168.102
    ```

    *(Sample output; your times may differ:)*

    ```text
    PING 192.168.168.102 (192.168.168.102) 56(84) bytes of data.
    64 bytes from 192.168.168.102: icmp_seq=1 ttl=64 time=0.047 ms
    64 bytes from 192.168.168.102: icmp_seq=2 ttl=64 time=0.067 ms

    --- 192.168.168.102 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1021ms
    rtt min/avg/max/mdev = 0.047/0.057/0.067/0.010 ms
    ```

7. Log out when finished:

    ```bash
    exit
    ```

    > **NOTE** - When you exit the shell, the container may stop. However, since you used the `--restart unless-stopped` (or `--restart always`) option when you created the container, if this occurs, the container will automatically restart upon exit, creating a new shell.

8. Perform the same tasks on the second container.

-----

## Access the Containers using HTTP

1. Get the contents of the first container's default web page:

    ```bash
    curl --silent 192.168.168.101:80 | grep title
    ```

    *(Sample output; your times may differ:)*

    ```text
    <title>Test Page for the HTTP Server on Red Hat Enterprise Linux</title>
    ```

    > **NOTE** - If you have a desktop environment like GNOME, you can open the page in a browser instead:
    >
    > ```bash
    > firefox 192.168.168.101:80
    > ```

2. Using an editor of your choice, create a file named `one.html` in your project directory with the following code:

    ```html
    <!DOCTYPE HTML>
    <html lang="en">
    <head>
        <META charset="UTF-8">
        <META name="viewport"
              content="width=device-width, initial-scale=1.0">
        <title>I Am One</title>
    </head>
    <body>
    <h1>Hello from Container Number One!</h1>
    </body>
    </html>
    ```

3. Copy the web page to the first container's Apache document root path; enter ***"Change.Me.123"*** when prompted for a password:

    ```bash
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null one.html alice@192.168.168.101:/var/www/html/index.html
    ```

4. Get the contents of the first container's default web page again:

    ```bash
    curl -# 192.168.168.101:80 | grep title
    ```

    *(Sample output; your times may differ:)*

    ```text
    <title>I Am One</title>
    ```

5. Perform the same tasks on the second container, but change `one.html` to `two.html` and replace ***"one"*** with ***"two"*** in the file contents.

-----

## Access the Containers through SSH

> **NOTE** -
>
> - Ensure you have installed the OpenSSH client on the development host: `sudo yum -y install openssh openssh-clients`
> - Ensure you have installed the sshpass utility on the development host: `python3 -m pip install sshpass`

1. Access the first container using SSH; enter ***"Change.Me.321"*** when prompted for a password:

    ```bash
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null alice@192.168.168.101
    ```

    *(Sample output; your container ID may differ:)*

    ```text
    Warning: Permanently added '192.168.168.101' (ECDSA) to the list of known hosts.
    alice@192.168.168.101's password: 
    [alice@fedcba012345 ~]# 
    ```

    > **NOTE** - If you receive the following warning:
    >
    > ```text
    > @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    > @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
    > @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    > IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
    > ```
    >
    > ...run the following command to remove the container's IPv4 address from your `~/.ssh/known_hosts` file:
    >
    > ```bash
    > ssh-keygen -R 192.168.168.101
    > ```

2. Look around:

    ```bash
    whoami
    pwd
    ls -l /var/www/html
    ```

    *(Sample output; your date may differ:)*

    ```text
    alice
    /home/alice
    -rw-r--r--. 1 alice alice 253 Jan 23 14:08 index.html
    ```

3. Log out when finished:

    ```bash
    logout
    ```

4. Perform the same tasks on the second container.

-----

## Stop and Start the Containers

1. Open a Terminal, if one is not already open.

2. To stop a container without deleting it:

    ```bash
    sudo podman stop demo_node1
    ```

3. To restart the container:

    ```bash
    sudo podman start demo_node1
    ```

## Clean Up (Optional)

To remove the containers, images, and network, use the following commands:

```bash
sudo podman stop demo_node2
sudo podman rm demo_node2
sudo podman stop demo_node1
sudo podman rm demo_node1
sudo podman rmi demo_image --force
sudo podman image prune --all --force
sudo podman network rm --force devnet
sudo systemctl stop podman
sudo systemctl disable podman
```

-----

## Extra Credit

If you want to explore containers without creating a containerfile or a network, you can run the following command:

```bash
# podman run --interactive --tty registry.access.redhat.com/ubi9/ubi bash
podman run -it registry.access.redhat.com/ubi9/ubi bash
```

-----

## Summary

In this tutorial, you have created a simple network of containers, with each container running an HTTP and SSH service. Please continue to the [Subversion Container Demo](/02-svn-container/02-svn-container.md). Remember, this is only a proof-of-concept demo for a single user; you should not use it for production.
