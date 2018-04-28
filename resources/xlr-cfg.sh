#!/usr/bin/bash
. ${XLR_ENV}

# Process xl-release.conf template
cat /xl-release.tmpl.conf | envsubst > ${XLR_CONF}/xl-release.conf

chmod 644 ${XLR_CONF}/xl-release.conf
chown -R ${RUN_USER}:${RUN_GROUP} ${XLR_CONF}/xl-release.conf

# Process xl-release-server.conf template
cat /xl-release-server.tmpl.conf | envsubst > ${XLR_CONF}/xl-release-server.conf

chmod 755 ${XLR_CONF}/xl-release-server.conf
chown -R ${RUN_USER}:${RUN_GROUP} ${XLR_CONF}/xl-release-server.conf
