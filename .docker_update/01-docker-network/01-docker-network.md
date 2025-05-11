# Create a Network of Docker Containers

> **NOTES:**
>
> - If Docker is not installed on your system, follow the instructions at <https://docs.docker.com/engine/install/> to install and start the Docker engine on your operating system.
> - For this demo, I use the "long" version of Docker commands. For command aliases and a full list of Docker CLI commands, see <https://docs.docker.com/reference/cli/docker/>.
> - Since the Docker daemon runs as root, you must run Docker commands with elevated privileges. You have three options:
>   1. Run the commands within a root user shell (e.g., `sudo su -`). This option allows you to run Docker and Linux commands using elevated privileges, even incorrect commands that may crash your system.
>   2. Add yourself to the `docker` group (created during the Docker installation) using `sudo usermod -aG docker $USER`. This option allows you to run Docker commands without `sudo`. If you have other users, they must be added to the `docker` group as well.
>   3. Execute each Docker command using `sudo` (used in this demo). This option forces you (and any other users) to explicitly and deliberately run the command using elevated privileges.

-----

## Create a Docker Network

```sh
# Ensure Docker is installed and running
# If not, install and start Docker before continuing
docker --version
systemctl --no-pager status docker
# Create a container network named "demo_net"
# Optional: Remove any old networks first
sudo docker network rm --force demo_net || true
# Verify that the gateway IP (192.168.168.1) is not already used on your host network
# If so, replace with an unused subnet (e.g., 192.168.170.1, etc.)
ip addr | grep 192.168.168.1
# Create the container network
sudo docker network create --driver bridge --subnet 192.168.168.0/24 --gateway 192.168.168.1 demo_net
# Check your work
sudo docker network ls --filter name=demo_net && sudo docker inspect demo_net
```

-----

## Create a Dockerfile

Using an editor of your choice, create a file named `demo.dockerfile` with the following code:

```dockerfile
# Pull the Docker image
# In this case, you are using the Red Hat 8 Universal Base Image
FROM registry.access.redhat.com/ubi8

# Set the working directory for subsequent Dockerfile instructions
WORKDIR /var/www/html

# Ensure the system is up-to-date
RUN dnf -y clean all && dnf -y update

# Ensure the httpd package and ping utility are installed
RUN dnf -y install httpd iputils

# Reduce the size of the final image by removing any metadata
# collected during installation of the packages
RUN dnf -y clean all && \
    rm -rf /var/cache/dnf

# Allow traffic through port 80 (HTTP)
EXPOSE 80

# Start the httpd service
ENTRYPOINT ["/usr/sbin/httpd"]
CMD ["-D", "FOREGROUND"]
```

-----

## Build a Docker Image

```sh
# Optional / Remove any old, unused, or intermediate images
sudo docker image rm demo_image --force || true
sudo docker image prune --force || true

# Build the image
# IMPORTANT! Make sure your dockerfile is in the current directory
sudo docker buildx build --tag=demo_image --file=demo.dockerfile .

# Check your work
sudo docker image ls demo_image
sudo docker inspect demo_image
```

-----

## Create and Add Docker Containers to the Docker Network

Create two demo nodes and attach them to the network:

```sh
# Optional / Stop and remove old nodes
sudo docker container stop demo_cont_1 || true
sudo docker container rm demo_cont_1 || true
sudo docker container stop demo_cont_2 || true
sudo docker container rm demo_cont_2 || true

# Create the nodes and attach them to the network
sudo docker container run --detach --tty --restart unless-stopped --name=demo_cont_1 --hostname=demo_cont_1 --network=demo_net --ip=192.168.168.101 demo_image
sudo docker container run -dt --restart unless-stopped --name demo_cont_2 -h demo_cont_2 --net demo_net --ip 192.168.168.102 demo_image

# Check your work
sudo docker container list --filter ancestor=demo_image
sudo docker inspect demo_cont_1 --format '{{ .NetworkSettings.Networks.demo_net.IPAddress }}'
sudo docker inspect demo_cont_2 -f '{{ .NetworkSettings.Networks.demo_net.IPAddress }}'
ping -c 2 192.168.168.101
ping -c 2 192.168.168.102
```

-----

## Check Connectivity

Check connectivity from within the first container:

```sh
# Enter the first container
sudo docker container exec --interactive --tty demo_cont_1 /bin/bash
# Ping the second container from within the first
ping -c 2 192.168.168.102
# Exit the container when finished
exit
```

Repeat these steps with `demo_cont_2`, but ping `192.168.168.101` instead.

Access the web server of the first container:

```sh
curl --silent 192.168.168.101:80 | grep title
firefox 192.168.168.101:80
```

Repeat these steps with the second container, switching the name and IPv4 addresses:

```sh
sudo docker container exec -it demo_cont_2 /bin/bash
ping -c 2 192.168.168.101
exit
curl -s 192.168.168.102:80 | grep title
firefox 192.168.168.102:80
```

-----

## Update the Landing Page

Using an editor of your choice, create a file named `index.html` with the following code:

```html
<!DOCTYPE HTML>
<html lang="en">
<head>
    <META charset="UTF-8">
    <META name="viewport"
          content="width=device-width, initial-scale=1.0">
    <title>Container One</title>
</head>
<body>
<h1>Hello from Container One!</h1>
</body>
</html>
```

Transfer it to the first container:

```sh
sudo docker container cp index.html demo_cont_1:/var/www/html/index.html
sudo docker container exec demo_cont_1 chown apache:apache /var/www/html/index.html
```

Access the container's web server:

```sh
curl --silent 192.168.168.101:80 | grep title
firefox 192.168.168.101:80
```

Repeat these steps with the second container:

```sh
cp index.html index2.html
sed -i 's/Container One/Container Two/' index2.html
sudo docker container cp index2.html demo_cont_2:/var/www/html/index.html
curl -s 192.168.168.101:80 | grep title
firefox 192.168.168.101:80
```

-----

## Check the Logs

To see what is going on behind the scenes, you can look at or follow your container's log:

```sh
sudo docker logs --follow demo_cont_1
```

-----

## Stop the Containers

If you will use the containers again, but want to stop them:

```sh
sudo docker container stop demo_cont_1
sudo docker container stop demo_cont_2
```

-----

## Clean Up (Optional)

To remove the containers, images, and network, use the following commands:

```sh
sudo docker container stop demo_cont_2
sudo docker container rm demo_cont_2
sudo docker container stop demo_cont_1
sudo docker container rm demo_cont_1
sudo docker image rm demo_image --force
sudo docker image prune --force
sudo docker network rm --force demo_net
```
