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

# Ensure Subversion is installed
RUN yum install -y subversion mod_dav_svn

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
    cd /var/www/svn &&\
    svnadmin create demorepo

# To prevent the following issues:
# svn: E000013: Can't open file '/var/www/svn/demorepo/db/txn-current-lock': Permission denied
# Warning: post commit FS processing had error: sqlite[S8]: attempt to write a readonly database
RUN chown -R apache:apache /var/www/svn/demorepo
RUN chmod -R 764 /var/www/svn/demorepo

# # Apply SELinux rules if enabled
RUN #!/bin/bash \
    selinuxenabled \
    if [ $? -ne 0 ]; then \
        chcon -R -t httpd_sys_content_t /var/www/svn/demorepo \
        chcon -R -t httpd_sys_rw_content_t /var/www/svn/demorepo \
    fi

# Install Java
RUN yum -y install java-17-openjdk-devel

# Ensure wget and unzip are installed
RUN yum -y install wget && yum -y install unzip

# Download and extract SonarScanner
RUN mkdir --parents /opt
RUN wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
RUN unzip sonar-scanner-cli-5.0.1.3006-linux.zip -d /opt
# FYI: Unzip changes the name (removing the -cli part)
RUN mv /opt/sonar-scanner-5.0.1.3006-linux /opt/sonar-scanner
RUN rm -f sonar-scanner-cli-5.0.1.3006-linux.zip
RUN export PATH=/opt/sonar-scanner/bin:$PATH

# Create a SonarQube user
# id -u sonaruser &>/dev/null || useradd --home-dir /opt/sonar-scanner --groups wheel --system sonaruser
RUN useradd -c "SonarScanner Account" -d /opt/sonar-scanner -G wheel -r sonaruser &&\
    echo Change.Me.123 | passwd sonaruser --stdin &&\
    chown -R sonaruser:sonaruser /opt/sonar-scanner &&\
    chmod 775 -R /opt/sonar-scanner

# Allow traffic through ports 22 (SSH), 80 (HTTP), and SVN (3690)
EXPOSE 22 80 3690

# Ensure the system is still up-to-date
RUN yum -y update

# Start the systemd service
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman#starting_services_within_a_container_using_systemd
CMD [ "/sbin/init" ]