#!/bin/bash

#cd $HIVE_HOME
#./bin/schematool -initSchema -dbType derby


echo "Starting postgresql server..."
/etc/init.d/postgresql start

#echo "Starting postgresql server..."
#$POSTGRESQL_BIN --config-file=$POSTGRESQL_CONFIG_FILE &


#start hadoop bootstrap script
/etc/bootstrap.sh

# start hive metastore server
$HIVE_HOME/bin/hive --service metastore &

sleep 5

# start hive server
$HIVE_HOME/bin/hive --service hiveserver2

# start hive metastore server
#$HIVE_HOME/bin/hive --service metastore &
#export HIVE_CONF_DIR=/etc/hive/conf/conf.server
#hive --service metatool -listFSRoot &

#sleep 5

# start hive server
#hive --service hiveserver2
