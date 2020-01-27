#!/bin/sh
#####################################################################
#
#   Postgresql Database Backup Script 
#   Written By: Sivaguru VINAYAGAM
#   URL: https://github.com/vsivaguru/Scripts/
#   Version 1.0
#    Last Update: Jan 27, 2020
#
#####################################################################

# Variables a modifier #
Port="5432"
Client="siclaranetfr-gedplateformes"
#clacon-ed01.adm.fr.clara.net
Host=10.129.60.89
PGDUMPDIR=/data/temp/confluence_backup/
#PGDUMPDIR=/data/temp/
error=0

TODAY=`date +%Y%m%d_%Hh%M`

# Clean before backup
CLEAN() {
    rm -Rf ${PGDUMPDIR}/*.sql
}
# Get the Database list
LISTDB() {
    dbs=`su - postgres -c "psql -t -c \"SELECT datname FROM pg_database WHERE datallowconn;\""`
    if [ $? -ne 0 ]; then
        echo "Can't connect to the Postgresql instance"
        let $[error=$error+1]
    fi
}

# Backup postgresql
BACKUP_DATABASE() {
    su - postgres -c "pg_dump -d confluence > ${PGDUMPDIR}/confluence_${ladate}.sql""
    if [ $? -ne 0 ]; then
        echo 'Probleme de backup des roles PostgreSQL'
        let $[error=$error+1]
    fi
        scp ${PGDUMPDIR}/confluence_${ladate}.sql claranet@clacon-ed02:/data/temp/
    done
}


ERR_RPT() {
    echo "Error(s) : $error"
    if [ $error -gt 0 ]; then
        echo "Problem : $error error(s)"
    fi

    exit $error
}

# main
LISTDB
CLEAN
BACKUP_DATABASE
BACKUP_DB
