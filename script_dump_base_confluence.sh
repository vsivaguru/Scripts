#!/bin/bash

su - postgres
psql -hclacon-p-pgpool-vip.adm.fr.clara.net -p 9999 -U postgres -c 'show pool_nodes;'

#identifier primary

#supression de dump /data/temp

su - postgres
pg_dump -d confluence > /data/temp/confluence_YYYYMMDD.sql #date du jour


#se connecter sur clacon-pa01-bkp
#supression de dump existant sur /srv/temp/
rm -rf /srv/temp/*

scp /data/temp/confluence_YYYYMMDD.sql claranet@clacon-pa01-bkp:/srv/temp/


exit la session postgres
se connecter 
su - confluence
#rsync -arP --files-from=<confluence-home>/rsync-include.lst <confluence-home> <dest>:.
rsync -arP --files-from=./rsync-include.lst . clacon-pa01-bkp:.

se connecter claranet@clacon-pa01-bkp
