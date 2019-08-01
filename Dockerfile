FROM ubuntu:latest

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -yq curl software-properties-common

# install java
RUN apt-get install -y openjdk-8-jdk

RUN apt-get install -y wget

# install hadoop
ENV HADOOP_VERSION 2.7.7
RUN wget -O hadoop-$HADOOP_VERSION.tar.gz   http://apache.claz.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz && \
  tar -xzf hadoop-$HADOOP_VERSION.tar.gz && \
  mv hadoop-$HADOOP_VERSION /usr/local/hadoop

ENV HADOOP_HOME /usr/local/hadoop
ENV HADOOP_INSTALL $HADOOP_HOME
ENV PATH $PATH:$HADOOP_INSTALL/sbin
ENV HADOOP_MAPRED_HOME $HADOOP_INSTALL
ENV HADOOP_COMMON_HOME $HADOOP_INSTALL
ENV HADOOP_HDFS_HOME $HADOOP_INSTALL
ENV YARN_HOME $HADOOP_INSTALL
ENV PATH $HADOOP_HOME/bin:$PATH

RUN cp $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-2.7.7.jar $HADOOP_HOME/share/hadoop/common/lib/
RUN cp $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-1.7.4.jar $HADOOP_HOME/share/hadoop/common/lib/

# to configure postgres as hive metastore backend
RUN apt-get -yq install vim postgresql postgresql-contrib libpostgresql-jdbc-java

# create metastore db, hive user and assign privileges
USER postgres
RUN /etc/init.d/postgresql start &&\
     psql --command "CREATE DATABASE metastore;" &&\
     psql --command "CREATE USER hive WITH PASSWORD 'hive';" && \
     psql --command "ALTER USER hive WITH SUPERUSER;" && \
     psql --command "GRANT ALL PRIVILEGES ON DATABASE metastore TO hive;"

# revert back to default user
USER root

# dev tools to build
RUN apt-get update
RUN apt-get install -y git libprotobuf-dev protobuf-compiler

# install maven
RUN apt-get install -y maven


# clone and compile hive
ENV HIVE_VERSION 2.1.3-inm-fix-SNAPSHOT
RUN cd /usr/local && git clone https://github.com/InMobi/hive.git
RUN cd /usr/local/hive && mvn clean install -DskipTests -Phadoop-2,dist
ENV HIVE_VERSION 2.1.3-inm-fix
RUN mkdir /usr/local/hive-dist && tar -xf /usr/local/hive/packaging/target/apache-hive-${HIVE_VERSION}-bin.tar.gz -C /usr/local/hive-dist

# set hive environment
ENV HIVE_HOME /usr/local/hive-dist/apache-hive-${HIVE_VERSION}-bin
ENV HIVE_CONF $HIVE_HOME/conf
ENV PATH $HIVE_HOME/bin:$PATH

# add postgresql jdbc jar to classpath
RUN ln -s /usr/share/java/postgresql-jdbc4.jar $HIVE_HOME/lib/postgresql-jdbc4.jar

# to avoid psql asking password, set PGPASSWORD
ENV PGPASSWORD hive

# initialize hive metastore db
RUN /etc/init.d/postgresql start && \
  wget https://raw.githubusercontent.com/InMobi/hive/develop/metastore/scripts/upgrade/postgres/hive-schema-2.1.0.postgres.sql &&\
  wget https://raw.githubusercontent.com/InMobi/hive/develop/metastore/scripts/upgrade/postgres/hive-txn-schema-2.1.0.postgres.sql &&\
 	psql -h localhost -U hive -d metastore -f hive-schema-2.1.0.postgres.sql

# copy config, sql, data files to /opt/files
RUN mkdir /opt/files
ADD hive-site.xml /opt/files/
ADD hive-log4j.properties /opt/files/
ADD hive-site.xml $HIVE_CONF/hive-site.xml
ADD hive-log4j.properties $HIVE_CONF/hive-log4j.properties
ADD core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml
ADD store_sales.* /opt/files/
ADD datagen.py /opt/files/

# set permissions for hive bootstrap file
ADD hive-bootstrap.sh /etc/hive-bootstrap.sh
RUN chown root:root /etc/hive-bootstrap.sh
RUN chmod 700 /etc/hive-bootstrap.sh

# To overcome the bug in AUFS that denies postgres permission to read /etc/ssl/private/ssl-cert-snakeoil.key file.
# https://github.com/Painted-Fox/docker-postgresql/issues/30
# https://github.com/docker/docker/issues/783
# To avoid this issue lets disable ssl in postgres.conf. If we really need ssl to encrypt postgres connections we have to fix permissions to /etc/ssl/private directory everytime until AUFS fixes the issue
#ENV POSTGRESQL_MAIN /var/lib/postgresql/9.3/main/
#ENV POSTGRESQL_CONFIG_FILE $POSTGRESQL_MAIN/postgresql.conf
#ENV POSTGRESQL_BIN /usr/lib/postgresql/9.3/bin/postgres
#ADD postgresql.conf $POSTGRESQL_MAIN
#RUN chown postgres:postgres $POSTGRESQL_CONFIG_FILE

ENV JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
