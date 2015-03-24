# PostgreSQL image for Docker
The idea behind this image is to have a Postgres service running on a Docker container in order to build a virtualized environment in a few easy steps. Data directories, users, databases and privileges are easily configurable, passing environment variables to the Docker command we can indicate the needded database schemas to be created and the users (with their passwords) that should be in use for the instance. The usage of Docker data volumes parameters will enable the persistence of the instance's data, so once the correct environment gets completely set the information won't be lost (and in fact will also enable data sharing between multiple instances).

## Basic Usage
The easiest way to run this image is to pass the Docker command the user and its password so the init script will then create them for us. 
```
  docker run --name postgresql -d \
    -e 'DB_USER=dbuser' -e 'DB_PASS=dbpass' \
    prodriguezdefino/postgresql
```
Afterwards those credentials can be used to login in the database instance. If the user already exists in the instance there will not be any changes in it. If no password is provided then no user will be created. 

Also it is possible to create a database in the new container instance adding the environment variable ```DB_NAME=dbname```.

Finally, if all the clients will be located in the same network the environment variable ```PSQL_TRUST_LOCALNET=true``` can be used to trust the connections and the instance will not ask for a password to establish them (use it with caution). This env variable will modify ```pg_hba.conf``` to achieve the desired results.

## Disclaimer
This Docker image is strongly based in the [sameersbn/docker-postgresql](https://github.com/sameersbn/docker-postgresql) image, thanks for the hard work of putting this pieces together.
