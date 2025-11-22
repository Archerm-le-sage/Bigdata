#!/bin/bash
apt update -y
apt install -y default-jdk

# Télécharger Spark
cd /opt
wget https://archive.apache.org/dist/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz
tar -xvf spark-3.5.0-bin-hadoop3.tgz
ln -s spark-3.5.0-bin-hadoop3 spark

# Configurer spark-env.sh
cat <<EOF > /opt/spark/conf/spark-env.sh
SPARK_MASTER_HOST=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/hostname -H "Metadata-Flavor: Google")
SPARK_MASTER_PORT=7077
SPARK_MASTER_WEBUI_PORT=8080
EOF

/opt/spark/sbin/start-master.sh
