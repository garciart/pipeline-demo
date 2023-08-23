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
