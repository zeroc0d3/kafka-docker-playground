#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/../../environment/sasl-ssl/start.sh "${PWD}/docker-compose.sasl-ssl.yml"


echo "########"
echo "##  SSL authentication"
echo "########"

echo "Sending messages to topic test-topic-ssl"
seq 10 | docker exec -i broker kafka-console-producer --broker-list broker:9091 --topic test-topic-ssl --producer.config /etc/kafka/secrets/client_without_interceptors.config

echo "Creating Confluent Replicator connector with SSL authentication"
docker exec connect \
     curl -X POST \
     --cert /etc/kafka/secrets/connect.certificate.pem --key /etc/kafka/secrets/connect.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt \
     -H "Content-Type: application/json" \
     --data '{
          "name": "duplicate-topic-ssl",
          "config": {
                    "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
                    "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                    "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                    "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                    "src.consumer.group.id": "duplicate-topic",
                    "confluent.topic.bootstrap.servers": "broker:11091",
                    "confluent.topic.replication.factor": "1",
                    "confluent.topic.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "confluent.topic.ssl.keystore.password" : "confluent",
                    "confluent.topic.ssl.key.password" : "confluent",
                    "confluent.topic.ssl.truststore.location" : "/etc/kafka/secrets/kafka.connect.truststore.jks",
                    "confluent.topic.ssl.truststore.password" : "confluent",
                    "confluent.topic.ssl.keystore.type" : "JKS",
                    "confluent.topic.ssl.truststore.type" : "JKS",
                    "confluent.topic.security.protocol" : "SSL",
                    "provenance.header.enable": true,
                    "topic.whitelist": "test-topic-ssl",
                    "topic.rename.format": "test-topic-ssl-duplicate",
                    "dest.kafka.bootstrap.servers": "broker:11091",
                    "dest.kafka.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "dest.kafka.ssl.keystore.password" : "confluent",
                    "dest.kafka.ssl.key.password" : "confluent",
                    "dest.kafka.ssl.truststore.location" : "/etc/kafka/secrets/kafka.connect.truststore.jks",
                    "dest.kafka.ssl.truststore.password" : "confluent",
                    "dest.kafka.security.protocol" : "SSL",
                    "src.kafka.bootstrap.servers": "broker:11091",
                    "src.kafka.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "src.kafka.ssl.keystore.password" : "confluent",
                    "src.kafka.ssl.key.password" : "confluent",
                    "src.kafka.ssl.truststore.location" : "/etc/kafka/secrets/kafka.connect.truststore.jks",
                    "src.kafka.ssl.truststore.password" : "confluent",
                    "src.kafka.security.protocol" : "SSL"
          }}' \
     https://localhost:8083/connectors | jq .



sleep 10

echo "Verify we have received the data in test-topic-ssl-duplicate topic"
docker exec broker kafka-console-consumer --bootstrap-server broker:9091 --topic test-topic-ssl-duplicate --from-beginning --max-messages 10 --consumer.config /etc/kafka/secrets/client_without_interceptors.config


echo "########"
echo "##  SASL_SSL authentication"
echo "########"

echo "Sending messages to topic test-topic-sasl-ssl"
seq 10 | docker exec -i broker kafka-console-producer --broker-list broker:9091 --topic test-topic-sasl-ssl --producer.config /etc/kafka/secrets/client_without_interceptors.config

echo "Creating Confluent Replicator connector with SASL_SSL authentication"
docker exec connect \
     curl -X POST \
     --cert /etc/kafka/secrets/connect.certificate.pem --key /etc/kafka/secrets/connect.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt \
     -H "Content-Type: application/json" \
     --data '{
          "name": "duplicate-topic-sasl-ssl",
          "config": {
                    "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
                    "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                    "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                    "header.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                    "src.consumer.group.id": "duplicate-topic",
                    "confluent.topic.bootstrap.servers": "broker:9091",
                    "confluent.topic.replication.factor": "1",
                    "confluent.topic.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "confluent.topic.ssl.keystore.password" : "confluent",
                    "confluent.topic.ssl.key.password" : "confluent",
                    "confluent.topic.security.protocol" : "SASL_SSL",
                    "confluent.topic.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required  username=\"client\" password=\"client-secret\";",
                    "confluent.topic.sasl.mechanism": "PLAIN",
                    "provenance.header.enable": true,
                    "topic.whitelist": "test-topic-sasl-ssl",
                    "topic.rename.format": "test-topic-sasl-ssl-duplicate",
                    "dest.kafka.bootstrap.servers": "broker:9091",
                    "dest.kafka.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "dest.kafka.ssl.keystore.password" : "confluent",
                    "dest.kafka.ssl.key.password" : "confluent",
                    "dest.kafka.security.protocol" : "SASL_SSL",
                    "dest.kafka.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required  username=\"client\" password=\"client-secret\";",
                    "dest.kafka.sasl.mechanism": "PLAIN",
                    "src.kafka.bootstrap.servers": "broker:9091",
                    "src.kafka.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "src.kafka.ssl.keystore.password" : "confluent",
                    "src.kafka.ssl.key.password" : "confluent",
                    "src.kafka.security.protocol" : "SASL_SSL",
                    "src.kafka.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required  username=\"client\" password=\"client-secret\";",
                    "src.kafka.sasl.mechanism": "PLAIN"
          }}' \
     https://localhost:8083/connectors | jq .


sleep 10

echo "Verify we have received the data in test-topic-sasl-ssl-duplicate topic"
docker exec broker kafka-console-consumer --bootstrap-server broker:9091 --topic test-topic-sasl-ssl-duplicate --from-beginning --max-messages 10 --consumer.config /etc/kafka/secrets/client_without_interceptors.config