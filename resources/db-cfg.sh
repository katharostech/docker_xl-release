#!/usr/bin/bash
. ${XLR_ENV}

# Process db drop and create scripts
cat /create_xl_dbs.tmpl.sql | envsubst > /create_xl_dbs.sql
