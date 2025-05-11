# Use Docker Compose to create a Network of Docker Containers

> **NOTES:**
>
> - If Docker is not installed on your system, follow the instructions at <https://docs.docker.com/engine/install/> to install and start the Docker engine on your operating system.
> - For this demo, I use the "long" version of Docker commands. For command aliases and a full list of Docker CLI commands, see <https://docs.docker.com/reference/cli/docker/>.
> - Since the Docker daemon runs as root, you must run Docker commands with elevated privileges. You have three options:
>   1. Run the commands within a root user shell (e.g., `sudo su -`). This option allows you to run Docker and Linux commands using elevated privileges, even incorrect commands that may crash your system.
>   2. Add yourself to the `docker` group (created during the Docker installation) using `sudo usermod -aG docker $USER`. This option allows you to run Docker commands without `sudo`. If you have other users, they must be added to the `docker` group as well.
>   3. Execute each Docker command using `sudo` (used in this demo). This option forces you (and any other users) to explicitly and deliberately run the command using elevated privileges.

-----

## Create a docker-compose File

Docker Compose allows you consolidate network, image, and container creation and assignment into a single YAML file.

Using an editor of your choice, create a file named `docker-compose.yml` with the following code:

> **NOTE** - Docker Compose networks come with an internal DNS resolver, so specifying the subnet, gateway, and static IPv4 addresses is not necessary. You will add them here to match the previous demo.

```yaml
---
# Add a network to allow the host and containers to communicate with each other
networks:
  demo_net:
    # Explicitly state the name so Docker does not prepend it with the directory name
    # (e.g., 01-docker-network_demo_net)
    name: demo_net
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.168.0/24
          gateway: 192.168.168.1

# Define the containers (services) you want to run
# Each one will be a separate container with its own configuration
services:
  demo_cont_1:
    build:
      context: .
      dockerfile: demo.dockerfile
    image: demo_image
    container_name: demo_cont_1
    hostname: demo_cont_1
    networks:
      demo_net:
        ipv4_address: 192.168.168.101
    ports:
      # Expose on host port 80
      - "80:80"

  demo_cont_2:
    # Reuse image built by demo_cont_1
    image: demo_image
    container_name: demo_cont_2
    hostname: demo_cont_2
    networks:
      demo_net:
        ipv4_address: 192.168.168.102
    ports:
      # Expose on host port 80
      - "80:80"
...
# code: language=yaml
# vi: set noai nu ts=2 sw=2 sts=2 sta et:
```

Build the network, image, and containers:

```sh
# IMPORTANT! Make sure your dockerfile and the docker-compose.yml file are in the current directory
sudo docker compose up --detach
# Check your work
curl localhost:8081 | grep title
curl localhost:8082 | grep title
# Update landing page
sudo docker container cp index.html demo_cont_1:/var/www/html/index.html
sudo docker container cp index.html demo_cont_2:/var/www/html/index.html
# Check your work again
curl localhost:8081 | grep title
curl localhost:8082 | grep title
```

To clean up using Docker Compose, you can run the following command:

```sh
sudo docker compose down --volumes --rmi all
```

-----

## Use Docker Compose with Variables

To prevent repeating values (and possibly entering them incorrectly), you can use a environment file and Go-style variable substitution.

Using an editor of your choice, create a file named `.env` with the following code:

```Go
IMAGE_NAME=demo_image
CONTAINER1_NAME=demo_cont_1
CONTAINER2_NAME=demo_cont_2
HOST_PORT1=8081
HOST_PORT2=8082
NETWORK_NAME=demo_net
```

Using an editor of your choice, modify the `docker-compose.yml` with the following code:

```yaml
---
# Add a network to allow the host and containers to communicate with each other
networks:
  demo_net:
    # Explicitly state the name so Docker does not prepend it with the directory name
    # (e.g., 01-docker-network_demo_net)
    name: ${NETWORK_NAME}
    driver: bridge

# Define the containers (services) you want to run
# Each one will be a separate container with its own configuration
services:
  demo_cont_1:
    build:
      context: .
      dockerfile: demo.dockerfile
    image: ${IMAGE_NAME}
    container_name: ${CONTAINER1_NAME}
    hostname: ${CONTAINER1_NAME}
    networks:
      demo_net:
        aliases:
          - demo1.local
    ports:
      # Expose on host port 8081
      - "${HOST_PORT1}:80"

  demo_cont_2:
    # Reuse image built by demo_cont_1
    image: ${IMAGE_NAME}
    container_name: ${CONTAINER2_NAME}
    hostname: ${CONTAINER2_NAME}
    networks:
      demo_net:
        aliases:
          - demo2.local
    ports:
      # Expose on host port 8082
      - "${HOST_PORT2}:80"
...
# code: language=yaml
# vi: set noai nu ts=2 sw=2 sts=2 sta et:
```

Build the network, image, and containers:

```sh
# IMPORTANT! Make sure your dockerfile and the docker-compose.yml file are in the current directory
sudo docker compose up --detach
# Check your work
curl localhost:8081 | grep title
curl localhost:8082 | grep title
```
