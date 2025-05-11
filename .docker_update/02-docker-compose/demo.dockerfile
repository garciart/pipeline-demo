# Pull the Docker image
# In this case, you are using the Red Hat 8 Universal Base Image
FROM registry.access.redhat.com/ubi8

# Ensure the system is up-to-date
RUN yum -y clean all && yum -y update

# Ensure the httpd package and ping utility are installed
RUN yum -y install httpd iputils

# Reduce the size of the final image by removing any metadata
# collected during installation of the packages
RUN yum clean all && \
    rm -rf /var/cache/yum

# Allow traffic through port 80 (HTTP)
EXPOSE 80

# Start the httpd service
ENTRYPOINT ["/usr/sbin/httpd"]
CMD ["-D", "FOREGROUND"]
