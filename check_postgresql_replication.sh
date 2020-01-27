#!/bin/sh

MASTER=$(. /etc/profile.d/postgresql.sh ; psql -hclacon-p-pgpool-vip.adm.fr.clara.net -p 9999 -U postgres -c "show pool_nodes" | awk -F "|" '/primary/{gsub(/ /, "", $0); print $2".adm.fr.clara.net"}')

SLAVE=$(. /etc/profile.d/postgresql.sh ; psql -hclacon-p-pgpool-vip.adm.fr.clara.net -p 9999 -U postgres -c "show pool_nodes" | awk -F "|" '/standby/{gsub(/ /, "", $0); print $2".adm.fr.clara.net"}')

SEUIL_NB_MINUTES_RETARD=30

SCRIPT_LOG_DIR=/data/logs/postgresql/replication/log_check_postgresql_replication
SCRIPT_LOG_FILE=${SCRIPT_LOG_DIR}/check_postgresql_repli__`date +%Y_%m_%d`.log

[ ! -d ${SCRIPT_LOG_DIR} ] && mkdir ${SCRIPT_LOG_DIR} && LogInfo "${SCRIPT_LOG_DIR} does not exist" && exit 1

LogInfo() {
    local timestamp=`date "+%Y_%m_%d__%H:%M:%S"`
    echo ${timestamp} $1 >> ${SCRIPT_LOG_FILE}
}

IS_MASTER() {
    MASTERHOSTNAME=$(su - postgres -c "ssh -o StrictHostKeyChecking=no -q postgres@${MASTER} hostname")
    MYHOSTNAME=`hostname`
    if [ "${MASTERHOSTNAME}" = "${MYHOSTNAME}" ];then
        echo "replication OK, you are on master so you have to check on slave"
        LogInfo "replication OK, you are on master"
        LogInfo "Fin excution du check replication PostgreSQL"
        exit 1
    fi
}

# AVEC PGPool, si le slave n'est pas renseigné (récupération dynamique de la liste des slaves)
# cela signifie que l'on est sur le master. Mais il aussi faut prendre en compte le cas où l'on a plusieurs slaves.
# Dans ce cas, le script de check n'est applicable que depuis les slaves.
# Pour ne pas lever d'alarme sur le master, le check ne fait que remonter un OK.
# Le check replication sera donc fait depuis les slaves.
# SANS PGPool, cette variable ne devrait jamais être vide.
if [ -z "${SLAVE}" ]
  then
    echo "replication OK, you use pgpool and are on primary"
    LogInfo "No slave set. Do not check replication"
    LogInfo "replication OK, you use pgpool and are on primary"
    exit 0
fi

LogInfo "Debut excution du check replication PostgreSQL"
IS_MASTER
IPSLAVE=`getent hosts ${SLAVE} | awk '{ print $1}'| uniq`

STATUS=`su - postgres -c "psql -h ${MASTER} -A -t -c \"select state from pg_stat_replication where client_addr = '${IPSLAVE}';\"" 2>/dev/null`
LogInfo "STATUT de replication = ${STATUS}"

# On donne un delai négatif lorsque l'on se trouve sur un maitre qui n'a jamais été esclave.
DELAY=`su - postgres -c "psql -A -t -c \"select COALESCE(extract (epoch from now()-pg_last_xact_replay_timestamp())::int/60,-10);\""`
LogInfo "Delai de replication = ${DELAY} minutes"
# lorsqu'il n'y a pas de transation sur le maitre le delay de réplication est important, il faut donc aussi vérifier le delta entre numéro de WAL.
NO_DIFF_WAL=`su - postgres -c "psql -A -t -c \"select pg_last_xlog_replay_location() = pg_last_xlog_receive_location();\""`
LogInfo "INFO : NO_DIFF_WAL = ${NO_DIFF_WAL}"

if [ "${NO_DIFF_WAL}" != "t" ] && [ ${DELAY} -ge ${SEUIL_NB_MINUTES_RETARD} ] && [ "${STATUS}" != "" ]
  then
    STATUS="retard_de_replication"
fi


case "${STATUS}" in
    streaming)
        echo "replication OK"
        LogInfo "replication OK"
    ;;
    catchup)
        echo "replication is late and trying to resynchronize"
        LogInfo "replication is late and trying to resynchronize"
    ;;
    retard_de_replication)
        echo "replication OK but is late and applying WAL (${DELAY} minutes)"
        LogInfo "replication is late and applying WAL (${DELAY} minutes)"
    ;;
    *)
        echo "replication is broken"
        LogInfo "replication is broken"
    ;;
esac

find ${SCRIPT_LOG_DIR} -type f -mtime +120 -exec rm {} \;

LogInfo "Fin excution du check replication PostgreSQL"
