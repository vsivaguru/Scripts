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
