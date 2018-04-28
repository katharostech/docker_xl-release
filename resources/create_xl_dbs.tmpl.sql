/****
** Prepare the Repository database
****/

USE master;
GO

-- Create the login
IF NOT EXISTS ( SELECT name
                FROM   master.sys.server_principals
                WHERE  name = N'${xlr_db_username}' )
BEGIN
    CREATE LOGIN [${xlr_db_username}] WITH PASSWORD = N'${xlr_db_password}'
END
GO

-- Create/Recreate the database
IF EXISTS (SELECT * FROM sys.databases WHERE name = '${xlr_db_name}')
    DROP DATABASE ${xlr_db_name};
GO
CREATE DATABASE ${xlr_db_name};
GO

-- Set default db for login
EXEC sp_defaultdb @loginame='${xlr_db_username}', @defdb='${xlr_db_name}'
GO

USE ${xlr_db_name}
GO

-- Create the schema
IF NOT EXISTS ( SELECT  *
                FROM    sys.schemas
                WHERE   name = N'${xlr_db_name}' )
    EXEC('CREATE SCHEMA [${xlr_db_name}] AUTHORIZATION [dbo]');
GO

-- Create the user
IF NOT EXISTS ( SELECT *
                FROM   sys.database_principals
                WHERE  name = N'${xlr_db_username}' )
BEGIN
    CREATE USER ${xlr_db_username}
    FOR LOGIN   ${xlr_db_username}
    WITH DEFAULT_SCHEMA = ${xlr_db_name}
END
GO

-- Add user to db_owner role for database
EXEC sp_addrolemember 'db_owner','${xlr_db_username}'
GO



/****
** Prepare the Archive database
****/
USE master;
GO

-- Create the login
IF NOT EXISTS ( SELECT name
                FROM   master.sys.server_principals
                WHERE  name = N'${xla_db_username}' )
BEGIN
    CREATE LOGIN [${xla_db_username}] WITH PASSWORD = N'${xla_db_password}'
END
GO

-- Create/Recreate the database
IF EXISTS (SELECT * FROM sys.databases WHERE name = '${xla_db_name}')
    DROP DATABASE ${xla_db_name};
GO
CREATE DATABASE ${xla_db_name};
GO

-- Set default db for login
EXEC sp_defaultdb @loginame='${xla_db_username}', @defdb='${xla_db_name}'
GO

USE ${xla_db_name}
GO

-- Create the schema
IF NOT EXISTS ( SELECT  *
                FROM    sys.schemas
                WHERE   name = N'${xla_db_name}' )
    EXEC('CREATE SCHEMA [${xla_db_name}] AUTHORIZATION [dbo]');
GO

-- Create the user
IF NOT EXISTS ( SELECT *
                FROM   sys.database_principals
                WHERE  name = N'${xla_db_username}' )
BEGIN
    CREATE USER ${xla_db_username}
    FOR LOGIN   ${xla_db_username}
    WITH DEFAULT_SCHEMA = ${xla_db_name}
END
GO

-- Add user to db_owner role for database
EXEC sp_addrolemember 'db_owner','${xla_db_username}'
GO
