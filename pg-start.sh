#!/bin/bash
set -e

PG_HOME="/var/lib/postgresql"
PG_CONFDIR="/etc/postgresql/${PG_VERSION}/main"
PG_BINDIR="/usr/lib/postgresql/${PG_VERSION}/bin"
PG_DATADIR="${PG_HOME}/${PG_VERSION}/main"

# set this env variable to true to enable a line in the
# pg_hba.conf file to trust samenet.  this can be used to connect
# from other containers on the same host without authentication
PSQL_TRUST_LOCALNET=${PSQL_TRUST_LOCALNET:false}

DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}
DB_UNACCENT=${DB_UNACCENT:false}

# fix permissions and ownership of ${PG_HOME}
mkdir -p -m 0700 ${PG_HOME}
chown -R postgres:postgres ${PG_HOME}

# fix permissions and ownership of /run/postgresql
mkdir -p -m 0755 /run/postgresql /run/postgresql/${PG_VERSION}-main.pg_stat_tmp
chown -R postgres:postgres /run/postgresql
chmod g+s /run/postgresql

# disable ssl
sed 's/ssl = true/#ssl = true/' -i ${PG_CONFDIR}/postgresql.conf

# listen on all interfaces
cat >> ${PG_CONFDIR}/postgresql.conf <<EOF
listen_addresses = '*'
EOF

if [ "${PSQL_TRUST_LOCALNET}" == "true" ]; then
  echo "Enabling trust samenet in pg_hba.conf..."
  cat >> ${PG_CONFDIR}/pg_hba.conf <<EOF
host    all             all             samenet                 trust
EOF
fi

# allow remote connections to postgresql database
cat >> ${PG_CONFDIR}/pg_hba.conf <<EOF
host    all             all             0.0.0.0/0               md5
EOF

cd ${PG_HOME}

# initialize PostgreSQL data directory
if [ ! -d ${PG_DATADIR} ]; then
  
  if [ ! -f "${PG_HOME}/pwfile" ]; then
    PG_PASSWORD=$(pwgen -c -n -1 14)
    echo "${PG_PASSWORD}" > ${PG_HOME}/pwfile
  fi

  echo "Initializing database..."
  sudo -u postgres -H "${PG_BINDIR}/initdb" \
    --pgdata="${PG_DATADIR}" --pwfile=${PG_HOME}/pwfile \
    --username=postgres --encoding=unicode --auth=trust >/dev/null
fi

if [ -f ${PG_HOME}/pwfile ]; then
  PG_PASSWORD=$(cat ${PG_HOME}/pwfile)
  echo "|------------------------------------------------------------------|"
  echo "| PostgreSQL User: postgres, Password: ${PG_PASSWORD}              |"
  echo "|                                                                  |"
  echo "| To remove the PostgreSQL login credentials from the logs, please |"
  echo "| make a note of password and then delete the file pwfile          |"
  echo "| from the data store.                                             |"
  echo "|------------------------------------------------------------------|"
fi

if [ -n "${DB_USER}" ]; then
  if [ -z "${DB_PASS}" ]; then
    echo ""
    echo "WARNING: "
    echo "  Please specify a password for \"${DB_USER}\". Skipping user creation..."
    echo ""
    DB_USER=
  else
    echo "Creating user \"${DB_USER}\"..."
    echo "CREATE ROLE ${DB_USER} with LOGIN CREATEDB PASSWORD '${DB_PASS}';" |
      sudo -u postgres -H ${PG_BINDIR}/postgres --single \
        -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql.conf >/dev/null
  fi
fi

if [ -n "${DB_NAME}" ]; then
  for db in $(awk -F',' '{for (i = 1 ; i <= NF ; i++) print $i}' <<< "${DB_NAME}"); do
    echo "Creating database \"${db}\"..."
    echo "CREATE DATABASE ${db};" | \
      sudo -u postgres -H ${PG_BINDIR}/postgres --single \
        -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql.conf >/dev/null

    if [ "${DB_UNACCENT}" == "true" ]; then
      echo "Installing unaccent extension..."
      echo "CREATE EXTENSION IF NOT EXISTS unaccent;" | \
        sudo -u postgres -H ${PG_BINDIR}/postgres --single ${db} \
          -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql.conf >/dev/null
    fi

    if [ -n "${DB_USER}" ]; then
      echo "Granting access to database \"${db}\" for user \"${DB_USER}\"..."
      echo "GRANT ALL PRIVILEGES ON DATABASE ${db} to ${DB_USER};" |
        sudo -u postgres -H ${PG_BINDIR}/postgres --single \
          -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql.conf >/dev/null
    fi
  done
fi

echo "Starting PostgreSQL server..."
exec sudo -u postgres -H ${PG_BINDIR}/postgres \
  -D ${PG_DATADIR} -c config_file=${PG_CONFDIR}/postgresql.conf
