FROM flink:1.20

ENV FLINK_HOME=/opt/flink

WORKDIR ${FLINK_HOME}

# Download connector library jars
RUN wget -P lib/plugin https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/9.3.0/mysql-connector-j-9.3.0.jar; \
    wget -P lib/plugin https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-mysql-cdc/3.4.0/flink-sql-connector-mysql-cdc-3.4.0.jar; \
    wget -P lib/plugin https://repo1.maven.org/maven2/org/apache/flink/flink-connector-jdbc/3.3.0-1.20/flink-connector-jdbc-3.3.0-1.20.jar; \
    wget -P lib/plugin https://repository.cloudera.com/repository/cloudera-repos/org/apache/flink/flink-shaded-hadoop-3/3.1.1.7.2.9.0-173-9.0/flink-shaded-hadoop-3-3.1.1.7.2.9.0-173-9.0.jar; \
    wget -P lib/plugin https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.1/flink-s3-fs-hadoop-1.20.1.jar; \
    wget -P lib/plugin https://repo1.maven.org/maven2/org/apache/paimon/paimon-flink-1.20/1.2.0/paimon-flink-1.20-1.2.0.jar; \
    wget -P lib/plugin https://repo1.maven.org/maven2/org/apache/paimon/paimon-s3/1.2.0/paimon-s3-1.2.0.jar; \
    wget -P lib/plugin https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-sqlserver-cdc/3.4.0/flink-sql-connector-sqlserver-cdc-3.4.0.jar;
