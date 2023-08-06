#!/usr/bin/bash
# My prep work
sudo dnf -y update
sudo dnf -y upgrade
sudo dnf -y clean all
sudo dnf -y autoremove
sudo subscription-manager repos --enable codeready-builder-for-rhel-8-$(arch)-rpms
sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo dnf -y install epel-release
sudo dnf -y install make gcc kernel-headers kernel-devel perl dkms bzip2
sudo dnf -y install git sshpass
sudo dnf -y isntall gnome-tweaks
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
sudo dnf check-update
sudo dnf install code
sudo dnf -y install cockpit
sudo systemctl enable --now cockpit.socket
sudo firewall-cmd --add-service=cockpit --permanent
sudo firewall-cmd --reload
mkdir Workspace
cd Workspace/
git clone https://github.com/garciart/pipeline-demo.git
sudo shutdown -r now

# Part 1: Create the Podman network
sudo systemctl start podman
sudo systemctl enable podman
# Optional; remove the network if it already exists
sudo podman network rm --force devnet
# Create the container network
sudo podman network create --driver bridge --subnet 192.168.168.0/24 --gateway 192.168.168.1 devnet
sudo podman network ls | grep devnet && sudo podman inspect devnet
touch managed_node.containerfile
cat <<EOF > managed_node.containerfile
# Pull a Docker or Podman image. For this demo, you will use AlmaLinux 8
FROM almalinux:8

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
RUN mkdir /var/run/sshd &&\
    ssh-keygen -A &&\
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak &&\
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config &&\
    cp /etc/pam.d/sshd /etc/pam.d/sshd.bak &&\
    sed 's@session\s*required\s*pam_loginuid.so@#session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Prevent 'System is booting up. Unprivileged users are not permitted to log in yet' error when not root
# Do not exit on error if the directory does not exist: rm /run/nologin || true
RUN rm /run/nologin || :

# Pass environment variables 
# https://stackoverflow.com/questions/36292317/why-set-visible-now-in-etc-profile
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Allow traffic through ports 22 (SSH) and 80 (HTTP)
EXPOSE 22 80

# Ensure the system is still up-to-date
RUN yum -y update

# Start the systemd service
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman#starting_services_within_a_container_using_systemd
CMD [ "/sbin/init" ]
EOF
# Optional; remove final and intermediate images if they exist
sudo podman rmi managed_node_image --force
sudo podman image prune --all --force
# Build the image
sudo podman build --rm --tag=managed_node_image --file=managed_node.containerfile
sudo podman images
# Optional; stop and remove the nodes if they exist
sudo podman stop managed_node1
sudo podman rm managed_node1
sudo podman stop managed_node2
sudo podman rm managed_node2
# Create the nodes and attach them to the network
sudo podman run --detach --tty --name=managed_node1 --replace --restart=unless-stopped --network=devnet --ip=192.168.168.101 --cap-add AUDIT_WRITE managed_node_image
sudo podman run -dt --name managed_node2 --replace --restart=unless-stopped --net devnet --ip 192.168.168.102 --cap-add AUDIT_WRITE managed_node_image
sudo podman ps --all
sudo podman inspect managed_node1 -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
sudo podman inspect managed_node2 -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
ping -c 2 192.168.168.101
ping -c 2 192.168.168.102
ssh-keygen -R 192.168.168.101

# # Ping container 2 from container 1
# sudo podman exec -it managed_node1 /usr/bin/bash
# ping -c 2 192.168.168.102
# exit

# # SSH into the containers
# sshpass -p Change.Me.321 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.168.101
# ping -c 2 192.168.168.102
# logout

# sshpass -p Change.Me.123 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null user@192.168.168.101
# sudo ping -c 2 192.168.168.102
# logout

firefox 192.168.168.101:80
touch one.html
cat <<EOF > one.html
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
EOF
firefox 192.168.168.101:80
touch two.html
cat <<EOF > two.html
<!DOCTYPE HTML>
<html lang="en">
<head>
    <META charset="UTF-8">
    <META name="viewport"
          content="width=device-width, initial-scale=1.0">
    <title>I Am Two</title>
</head>
<body>
<h1>Hello from Container Number Two!</h1>
</body>
</html>
EOF
firefox 192.168.168.102:80
sudo podman stop managed_node1
sudo podman start managed_node1
sudo podman stop managed_node2
sudo podman start managed_node2



# Part 2: Create the SVN container
touch subversion.conf
cat <<EOF > subversion.conf
<Location /svn>
    DAV svn
    SVNParentPath /var/www/svn/
    AuthType Basic
    AuthName "SVN Repository"
    AuthUserFile /etc/svn/svn-auth-users
    Require valid-user
</Location>
EOF
# Optional; remove old volumes if they exist
sudo podman volume prune --force
sudo podman volume rm svn-root --force
# Create the volume
sudo podman volume create svn-root
sudo podman volume inspect svn-root
touch svn.containerfile
cat <<EOF > svn.containerfile
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
# Install openssh, httpd, and sudo
RUN yum -y install openssh openssh-askpass openssh-clients openssh-server &&\
    yum -y install httpd &&\
    yum -y install sudo

# Enable the HTTP and SSH daemons
RUN systemctl enable httpd &&\
    systemctl enable sshd

# Customize the SSH daemon
RUN mkdir /var/run/sshd &&\
    ssh-keygen -A &&\
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak &&\
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config &&\
    cp /etc/pam.d/sshd /etc/pam.d/sshd.bak &&\
    sed 's@session\s*required\s*pam_loginuid.so@#session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Prevent 'System is booting up. Unprivileged users are not permitted to log in yet' error when not root
# Do not exit on error if the directory does not exist: rm /run/nologin || true
RUN rm /run/nologin || :

# Pass environment variables 
# https://stackoverflow.com/questions/36292317/why-set-visible-now-in-etc-profile
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Ensure Subversion is installed
RUN yum install -y subversion mod_dav_svn

# TODO: Name-based Virtual Host Support
RUN sed -i -E 's/^.?ServerName.*/ServerName svn.rgcoding.dev/g' /etc/httpd/conf/httpd.conf

# Add an Apache Subversion configuration file
ADD subversion.conf /etc/httpd/conf.d/subversion.conf

# Create a user in batch mode and set file permissions
RUN mkdir --parents /etc/svn &&\
    htpasswd -b -c /etc/svn/svn-auth-users svnuser Change.Me.123 &&\
    chown root:apache /etc/svn/svn-auth-users &&\
    chmod 640 /etc/svn/svn-auth-users

# Create a repository
RUN export LC_ALL=C &&\
    mkdir --parents /var/www/svn &&\
    cd /var/www/svn/ &&\
    svnadmin create demorepo

# To prevent the following issues:
# svn: E000013: Can't open file '/var/www/svn/demorepo/db/txn-current-lock': Permission denied
# Warning: post commit FS processing had error: sqlite[S8]: attempt to write a readonly database
RUN chown -R apache:apache /var/www/svn/demorepo/
RUN chmod -R 764 /var/www/svn/demorepo/

# # Apply SELinux rules if enabled
RUN #!/bin/bash\
    selinuxenabled\
    if [ $? -ne 0 ]; then\
        chcon -R -t httpd_sys_content_t /var/www/svn/demorepo/\
        chcon -R -t httpd_sys_rw_content_t /var/www/svn/demorepo\
    fi

# Allow traffic through ports 22 (SSH), 80 (HTTP), and SVN (3690)
EXPOSE 22 80 3690

# Start the systemd service
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman#starting_services_within_a_container_using_systemd
CMD [ "/sbin/init" ]
EOF
# Optional; remove final and intermediate images if they exist
sudo podman rmi svn_node_image --force
sudo podman image prune --all --force
# Build the image
sudo podman build --rm --tag=svn_node_image --file=svn.containerfile
sudo podman images
# Optional; stop and remove the node if it exists
sudo podman stop svn_node
sudo podman rm svn_node
# Create the node and attach it to the network
sudo podman run -dt --name svn_node --replace --restart=unless-stopped -v svn-root:/var/www/svn -w /var/www/svn --net devnet --ip 192.168.168.10 --cap-add AUDIT_WRITE svn_node_image
sudo podman ps --all
sudo podman inspect svn_node -f '{{ .NetworkSettings.Networks.devnet.IPAddress }}'
firefox 192.168.168.10/svn/demorepo

