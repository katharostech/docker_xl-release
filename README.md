# Build the image
```
docker build 
-t kadimasolutions/xl-release:trial_1.0.0 .
```

## Future image build
Currently we only have access to the trial download of XL Release. We plan on having access to all versions. When that happens, we will be able to build version specific images...
```
docker build 
--build-arg XLRELEASE_VERSION=[version] 
-t kadimasolutions/xl-release:[version] .
```

<a name="run-the-container"></a>
# Run the container

<a name="sandbox"></a>
## Sandbox
The quickest and easiest way to get going with this image is to use the built-in sandbox. The sandbox is simply a set of files that allow Docker Compose to quickly provision an environment for you, which is completely made up of containers. Here is a quick overview of the steps to get up and running quickly. Please note that this sandbox is setup to run in a two-node clustered configuration.

* [Prepare the external database container](#prepare-the-external-database-container)
* [Start the database container](#start-the-database-container)
* [Prepare the XL Release service](#prepare-the-xl-release-service)
* [Install XL Release](#install-xl-release)
* [Initialize XL Release](#initialize-xl-release)
* [Start the XL Release service](#start-the-xl-release-service)

<a name="prepare-the-external-database-container"></a>
### Prepare the external database container
<a name="mssql-environment-file"></a>
#### MSSQL Environment file
The environment file (.env) is used to pass environment variables to the docker-compose.yml file. Any variables declared here will be expanded for use by the YML. Currently it is only used to declare the host port in which to expose the MSSQL service on. 

***Update this .env file with whatever port suits your needs.***

<a name="mssql-secrets-file"></a>
#### MSSQL Secrets file
This file (mssqldevdb.scrt) is meant to hold sensitive information that should not be made publicly accessible. Most importantly it allows us to pass in credential information that is typically required to be passed in as command line environment variables. But since command line environment variables are exposed to anybody doing a "ps" command or a "docker inspect" command, we try to avoid secrets in command line environment variables. See the [MSSQL Docker Compose file](#mssql-docker-compose-file) section for more info on how we accomplish this.

A template file has been created (mssqldevdb.scrt.tmpl) that can be used to create your secrets file. Note that the [Docker Compose file](#mssql-docker-compose-file) is expecting the name of the secrets file to be "mssqldevdb.scrt". Use these steps to create the secrets file
```
> cd [your repo home]/docker_xl-release/sandbox/mssql
> cp mssqldevdb.scrt.tmpl mssqldevdb.scrt
> vi mssqldevdb.scrt
    - Update the SA password to your liking
> :wq
    - to save your work
```

<a name="mssql-docker-compose-file"></a>
#### MSSQL Docker Compose file
Docker Compose is the mechanism we use for easily standing up our development environments. It gives us fine grained control of how we spin up a stack, without having to run command line programs over and over. Here are some points to note about this particular Docker Compose file.
* The ${MSSQL_PORT} variable is defined by the aformentioned [.env file](#mssql-environment-file)
* The [Secrets file](#mssql-secrets-file) is mounted in to the container at `/secrets` from the host path `/tmp`. We use `/tmp` because of how we have our Docker hosts provisioned to work in our dev environments. Paths defined in our Docker Compose file are not referencing our local development system. They are actually referencing paths on our Docker Host which is provided by a VM we run via VirtualBox. Thus, depending on how your local dev environment is configured, you may choose to change this path accordingly. 
    * For our setup, we SCP the file to our Docker host into the `/tmp` directory, and then reference accordingly in the volumes section of our Docker Compose file.
* We are using the vendor provided container image. This is atypical for us since we will generally re-write any container to be hosted in RHEL. But for dev purposes, leaning on the vendors to provide the image is a time saver.
* We override the entrypoint and command of the vendor provided MSSQL container image in order to source the [Secrets file](#mssql-secrets-file). This is how we avoid passing in secrets at the command line. By sourcing our secrets file in the same shell session as the MSSQL server startup, our SA Password provided by our secrets file is injected into the startup of the process without exposing the password on the command line.

<a name="start-the-database-container"></a>
### Start the database container
Now that we have the [.env file](#mssql-environment-file) and the [Secrets file](#mssql-secrets-file) in place, Docker Compose will now be able to process the [Docker Compose file](#mssql-docker-compose-file) to startup the database instance with the defined SA Password and be exposed to the host using the defined port number.

```
# Startup the database instance
docker-compose up -d
# Follow the progress of the startup
docker-compose logs -f
# Check the status of the container
docker-compose ps
```

Keep in mind that the data volumes used to store the SQL Server data is not persisted outside of this container. If you want to do so, you will need to add the appropriate volume declarations as shown [here](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-configure-docker#persist).

<a name="prepare-the-xl-release-service"></a>
### Prepare the XL Release service
With a backend MSSQL Server running to host our clustered configuration, it is time to prep the XL Release service.
<a name="xlr-license-file"></a>
#### XLR License file
Unlike the MSSQL stack, we don't use a `.env` file; we chose to store all the variables in the secrets file. However, the license file is necessary to run XL Release, even in a dev capacity. This file can be obtained from [XebiaLabs](https://support.xebialabs.com/hc/en-us "XebiaLabs Support"). 

***The name expected by the [Docker Compose file](#xlr-docker-compose) is `xl-release-license.lic`. After acquiring the license file from XebiaLabs, place it into the `/tmp` directory of your Docker host, or wherever it might make sense for your environment.***

<a name="xlr-secrets-file"></a>
#### XLR Secrets file
The secrets file (xlr.env.scrt) is designed to be sourced throughout the container startup and configuration process. It has user names, passwords, port specs, etc. All variables that need to be passed into the spinup of of the application with the exception of the following cluster environment variables:
* xlr_cluster_mode
* xlr_cluster_name

All variables in this file are required in order to connect to the backed SQL Server instance. These variables are used to inject configuration information into the approporiate files for successful operation.

There is a template provided that can be copied to produce this file which has all the necessary variables defined for proper configuration. Simply copy the template file and alter the values according to your environment. Namely the SQL Server login information for both the SA Account password that was setup in the previous [MSSQL Secrets file](#mssql-secrets-file), as well as the intended user names and passwords required for the successful setup of XL Release as defined in [these steps to Install XL Release](#install-xl-release) outlined later in this article. There are two separate databases involved in supporting the XL Release instance:
* Repository database
* Archive database
These support the application respectively in the same manner that the embedded database does via the two file systems as noted [here](#embedded-database-configuration) (which is not supported by this image).

One last thing to note is the "`xlr_admin_password`" that is defined in the secrets file. It is the password that will be used to login as the "admin" account for XL Release. 

***Take these steps to setup your secrets file:***
```
> cd [your repo home]/docker_xl-release/sandbox
> cp xlr.env.scrt.tmpl xlr.env.scrt
> vi xlr.env.scrt
    - Update the SA password to match that which was previously configured on your MSSQL instance
    - Update intended username and password info for xlr DB and xla DB as well as the appropriate hosts and ports for the associated databases
> :wq
    - to save your work
```

<a name="xlr-docker-compose-file"></a>
#### XLR Docker Compose file
The Docker Compose file is setup to run XL Release in a two node active/active cluster. It is configured to spin up the two nodes on the same virtual network as the MSSQL instance so that it can easily connect to the DB instance. The only dependencies are the secrets file and the license file. Other than that, a simple "`docker-compose up -d`" command can be used to start up the cluster. 

Keep in mind that prior to the first time you spin up your cluster, you will need to step through the [Installation](#install-xl-release) and the [Initialization](#initialize-xl-release). 

Here are some things to note about the Docker Compose file:
* As stated, these nodes will startup in the "`mssql_default`" network which is the network that the SQL Server instance starts in by default.
* Although cluster mode is set to "full", this can be changed to the following values for different purposes...keeping in mind that other changes might be needed to faciilitate different modes:
    * default (single node, no cluster)
    * hot-standby (active/passive)
* The "`xlr_cluster_name`" and "`xlr_cluster_port`" should be the same in both nodes so that they are considered part of the same cluster as opposed to two single node clusters
* The exposed host ports are different so that each node is reachable on different ports on your host. This is necessary as only a single application can communicate on a given port on a given machine.

***To start your XL Release cluster, simply issue the following command in the "`sandbox`" directory:***
```
# Startup your cluster
docker-compose up -d
# Check the status as it starts up
docker-compose logs -f
# Check the status of the containers in your cluster
docker-compose ps
```

<a name="install-xl-release"></a>
### Install XL Release
The installation of XL Release is really just a process that we use to prime the database for running the application. Take extreme caution when using this option, ***ESPECIALLY IN PRODUCTION!!!***

Essentially, you should only run this once in Production. Possibly a few times if you are prepping production and have to restart for some reason. Running this installation will essentially drop the database if it exists and recreate it in the target SQL Server instance. This is great when you are in DEV because you can start over easily if you have to. But it also means that you can wipe out anything that you were doing in DEV.

Some things to note about the command:
* Need to pass in the network as this procedure has to connect to the database. \( [See the XLR Docker Compose file](#xlr-docker-compose-file) \)
* In the same fashion, the cluster mode, name, port, and volume mounts may need to be provided as well. If not, it doesn't hurt to provide them here. \( [See the XLR Docker Compose file](#xlr-docker-compose-file) \)
    * At a minimum, the volume mounts for the secrets file is necessary as it has the credentials used to setup the databases.
* Pretty sure running the install is what sets the admin password. The admin password is defined in the secrets file (`xlr.env.scrt`) and is injected into the "`xl-release-server.conf`" file.
    
***Run the following command to install XL Release:***

```
docker run \
--network mssql_default \
-e xlr_cluster_mode=full \
-e xlr_cluster_name=xlrcluster \
--volume /tmp/xlr.env.scrt:/secrets/xlr.env.scrt:Z \
--volume /tmp/xl2-release-license.lic:/secrets/xl-release-license.lic:Z \
-it kadimasolutions/xl-release:[version] install
```

<a name="initialize-xl-release"></a>
### Initialize XL Release
Initializing the cluster is a one time thing when the cluster is instantiated. It is a necessary step for both a stand-alone configuration or clustered configuration. It will reset the configuration to factory deffault. It may not be necessary to include the cluster configuration environment variables nor the [XLR Secrets file](#xlr-secrets-file) and the [XLR License file](#xlr-license-file) when running the initialization process, but we pass those in for thoroughness. You may also need to ensure connectivity to the DB as well for this step.

***Run the following command to initialize XL Release:***

```
docker run \
--network mssql_default \
-e xlr_cluster_mode=full \
-e xlr_cluster_name=xlrcluster \
--volume /tmp/xlr.env.scrt:/secrets/xlr.env.scrt:Z \
--volume /tmp/xl2-release-license.lic:/secrets/xl-release-license.lic:Z \
-it kadimasolutions/xl-release:[version] init
```

<a name="start-the-xl-release-service"></a>
### Start the XL Release service
Starting the cluster is simple with Docker Compose. As stated in the [XLR Docker Compose file](#xlr-docker-compose-file)...

***To start your XL Release cluster, simply issue the following command in the "`sandbox`" directory:***
```
# Startup your cluster
docker-compose up -d
# Check the status as it starts up
docker-compose logs -f
# Check the status of the containers in your cluster
docker-compose ps
```

<a name="setup-and-configuration"></a>
# Setup and Configuration
All of the necessary configuration has been identified above in the sandbox setup, so there is no reason to recap here since setting up a non-Production or even a Production environment will be similar depending on your delivery method and platform. However, there are some noteworthy subjects to review.

<a name="reverse-proxy-and-load-balancing"></a>
## Reverse Proxy and Load Balancing
In any clustered configuration, there is typically a web server which serves as the entrypoint to your cluster. There are many ways to accomplish this and is truly agnostic to the operation of this application cluster. Due to the countless ways to setup a load balancer/reverse proxy, we don't cover that topic here specifically. In our case, we will host a load balancer in Rancher that will do this job for us and it will be very easy. I like easy. However, you can stand up any number of web server applications, i.e. Apache, HA Proxy, Nginx, etc; that will do the trick as well. XebiaLabs has a section of their installation document dedicated to this very topic. You can read it [here](https://docs.xebialabs.com/xl-release/how-to/configure-cluster.html#step-5-set-up-the-load-balancer).

<a name="stand-alone-configuration"></a>
## Stand-alone configuration
Stand-alone configuration can be accomplished by setting the "`xlr_cluster_mode`" to "`default`" when installing, initializing and running. This is essentially a single node cluster configuration. The [Docker Compose file](#xlr-docker-compose-file) is configured with a two node cluster setup. A single node cluster setup might look something like the following:

```
version: '3'
networks:
  default:
    external:
      name: mssql_default
services:
    xlr-node1:
        image: dhaws/xl-release:trial_JFJ-4503_test1
        environment:
            xlr_cluster_mode: default
            xlr_cluster_name: xlrcluster
        volumes:
            - /tmp/xlr.env.scrt:/secrets/xlr.env.scrt:Z
            - /tmp/xl-release-license.lic:/secrets/xl-release-license.lic:Z
        ports:
            - 5516:5516
```
The only difference in the above configuration is the "`xlr_cluster_mode`" variable which has an assigned value of "`default`" instead of "`full`". The [Secrets file](#xlr-secrets-file) should see no change since all the data in that file is still required for a single node cluster setup.

<a name="database-configuration"></a>
## Database configuration

<a name="external-database-configuration"></a>
### External database configuration
All the configuration is done in XL_RELEASE_SERVER_HOME/conf/xl-release.conf, which is in HOCON format.

When you start the XL Release server for the first time, it will encrypt passwords in the configuration file and replace them with Base64-encoded encrypted values.

The database specific configuration file examples can be found at [Configure the SQL repository in a database (XL Release 7.5.x and later)](https://docs.xebialabs.com/xl-release/how-to/configure-the-xl-release-sql-repository-in-a-database.html#the-configuration-file). Use the examples to configure connections to whatever database backend you are using. The template used in this Docker image is for a SQL Server Backend. However, the other possible databases supported at the time of this writing are:
* PostgreSQL versions 9.3, 9.4, 9.5, 9.6, and 10.1
* MySQL versions 5.5, 5.6, and 5.7
* Oracle 11g
* Microsoft SQL Server 2012 and later
* DB2 versions 10.5 and 11.1

The way we have implemented external database configuration for this image is by using the SQL Server template combined with a [secrets file](#mssql-secrets-file) which names all the necessary environment variables. See [Prepare the external database container](#prepare-the-external-database-container) section for a solid breakdown.

<a name="embedded-database-configuration"></a>
### Embedded database configuration
***Not supported by this image***

Due to the ease of standing up an external database and the fact that it is a requirement to have an external database for a clustered configuration (our recommended mode of operation), and that XebiaLabs recommended configuration is an external database (embedded database is only recommended for demo/test environments), we do not at this time feel it necessary to support the embedded database. For informational purposes however, here are some snippets from the XL Release documentation regarding the embedded database.

---

XL Release stores its data in a repository. By default, this repository is an embedded database stored in XL_RELEASE_SERVER_HOME/repository. Completed releases and reporting information are stored in another database called archive. By default, this is also an embedded database stored in XL_RELEASE_SERVER_HOME/archive. The embedded databases are automatically created when XL Release is started for the first time.

The embedded databases provide an easy way to set up XL Release for evaluation or in a test environment. However, for production use, it is strongly recommended that you use an industrial-grade external database server. Storing the repository in an external database server is also required to run XL Release in a cluster setup (active/active or active/hot standby).

<a name="special-notes"></a>
##### SPECIAL NOTES
* The repository database and the archive database must not reside in the same database on the database server.
* You cannot migrate the repository from an embedded database to an external database. Ensure that you configure production setup with an external database from the start. When upgrading from a JCR-based version of XL Release (version 7.2.x or earlier), ensure that you migrate to an external database. For information about upgrading from XL Release 7.2.x or earlier, refer to Upgrade to XL Release 7.5.x for detailed instructions.

<a name="running-an-empty-xl-release-with-the-repository-stored-inside-the-docker-container"></a>
#### Running an empty XL Release with the repository stored inside the docker container
```
docker run \
-v /tmp/xl-release-license.lic:/secrets/xl-release-license.lic:Z \
-p 5516:5516 \
kadimasolutions/xl-release:[version]
```

<a name="running-an-empty-xl-release-with-the-repository-stored-outside-the-docker-container-as-a-volume"></a>
#### Running an empty XL Release with the repository stored outside the docker container as a volume
```
docker run \
--rm \
-v [repo_location]:/opt/xlr/server/repository:Z \
-v [archive_location]:/opt/xlr/server/archive:Z \
-v /tmp/xl-release-license.lic:/secrets/xl-release-license.lic:Z \
-p 5516:5516 \
kadimasolutions/xl-release:[version]
```

**NOTE**: When starting the container the **repository** and the **archive** should be empty or have been initialized at the same time

The license volume mount is needed to provide a valid license, or store a license when logging in the first time. To access the UI, browse to http://[docker_ip]:5516
