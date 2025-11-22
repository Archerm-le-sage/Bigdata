#!/bin/bash
apt update -y
apt install -y default-jdk

cd /opt
wget https://archive.apache.org/dist/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz
tar -xvf spark-3.5.0-bin-hadoop3.tgz
ln -s spark-3.5.0-bin-hadoop3 spark

MASTER_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/master-ip -H "Metadata-Flavor: Google")

cat <<EOF > /opt/spark/conf/spark-env.sh
SPARK_MASTER_URL=spark://$MASTER_IP:7077
SPARK_WORKER_CORES=1
SPARK_WORKER_MEMORY=512m
EOF

/opt/spark/sbin/start-worker.sh spark://$MASTER_IP:7077
