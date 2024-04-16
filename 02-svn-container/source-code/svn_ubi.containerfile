# Pull a Docker or Podman image. For this demo, you will use AlmaLinux 8
FROM registry.access.redhat.com/ubi8/ubi

# Ensure system is up-to-date
RUN yum -y update &&\
    yum -y upgrade &&\
    yum -y clean all &&\
    yum -y autoremove

# Install httpd and sudo
RUN yum -y install httpd &&\
    yum -y install sudo

# Enable the HTTP daemon
RUN systemctl enable httpd

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

# Allow traffic through ports 80 (HTTP) and SVN (3690)
EXPOSE 80 3690

# Ensure the system is still up-to-date
RUN yum -y update

# Start the systemd service
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_atomic_host/7/html/managing_containers/running_containers_as_systemd_services_with_podman#starting_services_within_a_container_using_systemd
CMD [ "/sbin/init" ]