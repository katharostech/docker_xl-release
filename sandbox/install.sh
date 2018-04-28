docker run \
--network mssql_default \
--rm \
-e xlr_cluster_mode=default \
-e xlr_cluster_name=xlrcluster \
--volume /tmp/xlr.env.scrt:/secrets/xlr.env.scrt:z \
--volume /tmp/xl-release-license.lic:/license/xl-release-license.lic:z \
-it kadimasolutions/xl-release:trial_1.0.0 install
