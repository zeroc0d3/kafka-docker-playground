#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


echo "Sending messages to topic http-messages"
seq 10 | docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic http-messages

echo "-------------------------------------"
echo "Running SSL Authentication Example"
echo "-------------------------------------"

echo "Creating HttpSinkSSL connector"
docker exec connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
          "name": "HttpSinkSSL",
          "config": {
               "topics": "http-messages",
               "tasks.max": "1",
               "connector.class": "io.confluent.connect.http.HttpSinkConnector",
               "key.converter": "org.apache.kafka.connect.storage.StringConverter",
               "value.converter": "org.apache.kafka.connect.storage.StringConverter",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1",
               "http.api.url": "https://http-service-ssl-auth-no-ssl-endpoint-identification:8443/api/messages",
               "auth.type": "BASIC",
               "connection.user": "admin",
               "connection.password": "password",
               "ssl.enabled": "true",
               "https.ssl.endpoint.identification.algorithm": "",
               "https.ssl.truststore.location": "/etc/kafka/secrets/localhost-keystore-no-ssl-endpoint-identification.jks",
               "https.ssl.truststore.type": "JKS",
               "https.ssl.truststore.password": "changeit",
               "https.ssl.keystore.location": "/etc/kafka/secrets/localhost-keystore-no-ssl-endpoint-identification.jks",
               "https.ssl.keystore.type": "JKS",
               "https.ssl.keystore.password": "changeit",
               "https.ssl.key.password": "changeit",
               "https.ssl.protocol": "TLSv1.2"
          }}' \
     http://localhost:8083/connectors | jq .


sleep 10

echo "Confirm that the data was sent to the HTTP endpoint."
curl -k --cacert ./security/myCertificate.crt -X GET https://admin:password@localhost:8543/api/messages | jq .


