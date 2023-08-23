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
