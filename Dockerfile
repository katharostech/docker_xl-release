################
# XL Release Image
################

# Set the base image
FROM registry.access.redhat.com/rhel7

# File Author / Maintainer
MAINTAINER dhaws opax@kadima.solutions

# Secrets are used for passing in sensitive creds and other info that is not wanted exposed as global ENV Variables. The license file is necessary to run the app. These files should be mounted into the container
ENV \
XLR_ENV=/secrets/xlr.env.scrt \
XLR_LIC=/license/xl-release-license.lic

# Root directory
ENV \
XLR_HOME=/opt/xlr/server

# XL Release directories
ENV \
XLR_TMP=${XLR_HOME}/tmp \
XLR_CONF=${XLR_HOME}/conf \
XLR_LIB=${XLR_HOME}/lib \
XLR_BIN=${XLR_HOME}/bin

# These directories can be mounted externally for persistence
ENV \
XLR_LOG=${XLR_HOME}/log \
XLR_EXT=${XLR_HOME}/ext \
XLR_PLUGINS=${XLR_HOME}/plugins \
XLR_HOTFIX=${XLR_HOME}/hotfix

# These variables should be passed in for cluster config settings,
# otherwise the following defaults will be used.
## Cluster mode values can be:
###  No cluster mode ###
##    "default"      (single node);
###  Cluster modes ###
##    "full"         (active/active);
##    "hot-standby"  (active/passive);
ENV \
xlr_cluster_mode=default \
xlr_cluster_name=xlrcluster \
xlr_cluster_port=5531

## These directories are only used if embedded database is used
ENV \
XLR_ARCHIVE=${XLR_HOME}/archive \
XLR_REPOSITORY=${XLR_HOME}/repository

# Non-privileged user
ENV \
RUN_USER=onek \
RUN_GROUP=devops

# Create unprivileged account
RUN \
groupadd ${RUN_GROUP} && \
useradd -g ${RUN_GROUP} ${RUN_USER}

# Create secrets and license directories
RUN set -x && \
mkdir /secrets && \
chown root:root /secrets && \
chmod 700 /secrets && \
mkdir /license && \
chown ${RUN_USER}:${RUN_GROUP} /license && \
chmod 755 /license

# Install any necessary utilities
RUN set -x && \
curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/7/prod.repo && \
yum -y install \
gettext \
java-1.8.0-openjdk-devel.x86_64 \
unzip \
wget && \
ACCEPT_EULA=Y yum -y install mssql-tools unixODBC-devel &&\
yum clean all && \
rm -rf /var/cache/yum

# Install XL Release
RUN wget --progress=dot:giga -O /tmp/xl-release-trial.zip https://dist.xebialabs.com/xl-release-trial.zip && \
mkdir -p /opt/xlr && \
unzip /tmp/xl-release-trial.zip -d /opt/xlr && \
mv /opt/xlr/xl-release-*-server /opt/xlr/server && \
rm -rf /tmp/xl-release-trial.zip

# Bring in dependent resources
COPY resources/xl-release-server.tmpl.conf /xl-release-server.tmpl.conf
COPY resources/synthetic.xml ${XLR_EXT}/synthetic.xml
COPY resources/mssql-jdbc-6.2.2.jre8.jar ${XLR_LIB}/mssql-jdbc-6.2.2.jre8.jar
COPY resources/xl-release.tmpl.conf /xl-release.tmpl.conf
COPY resources/xlr-cfg.sh /xlr-cfg.sh
COPY resources/db-cfg.sh /db-cfg.sh
COPY resources/create_xl_dbs.tmpl.sql /create_xl_dbs.tmpl.sql
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Link the mounted license file to config dir
RUN set -x && \
ln -fs ${XLR_LIC} ${XLR_CONF}/xl-release-license.lic

# Set perms on files copied in
RUN set -x && \
chmod 664 ${XLR_LIB}/mssql-jdbc-6.2.2.jre8.jar && \
chmod 744 /docker-entrypoint.sh && \
chmod 744 /xlr-cfg.sh && \
chmod 744 /db-cfg.sh && \
chmod 744 /xl-release.tmpl.conf && \
chmod 744 /create_xl_dbs.tmpl.sql && \
chmod 755 /xl-release-server.tmpl.conf && \
chown -R ${RUN_USER}:${RUN_GROUP} ${XLR_HOME}

EXPOSE 5516 5531

# Run this container as a program
ENTRYPOINT ["/docker-entrypoint.sh"]
# Run this on container startup
CMD ["run"]
