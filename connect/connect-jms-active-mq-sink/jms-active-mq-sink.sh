#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [ ! -f ${DIR}/activemq-all-5.15.4.jar ]
then
     echo "Downloading activemq-all-5.15.4.jar"
     wget http://central.maven.org/maven2/org/apache/activemq/activemq-all/5.15.4/activemq-all-5.15.4.jar
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


echo "Sending messages to topic sink-messages"
docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic sink-messages << EOF
This is my message
EOF

echo "Creating JMS ActiveMQ sink connector"
docker exec connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
               "name": "jms-active-mq-sink",
               "config": {
                    "connector.class": "io.confluent.connect.jms.JmsSinkConnector",
                    "topics": "sink-messages",
                    "java.naming.factory.initial": "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
                    "java.naming.provider.url": "tcp://activemq:61616",
                    "java.naming.security.principal": "admin",
                    "java.naming.security.credentials": "admin",
                    "connection.factory.name": "ConnectionFactory",
                    "jms.destination.type": "queue",
                    "jms.destination.name": "DEV.QUEUE.1",
                    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
                    "value.converter": "org.apache.kafka.connect.storage.StringConverter",
                    "confluent.license": "",
                    "confluent.topic.bootstrap.servers": "broker:9092",
                    "confluent.topic.replication.factor": "1"
          }}' \
     http://localhost:8083/connectors | jq .

sleep 5

echo "Get messages from DEV.QUEUE.1 JMS queue:"
curl -XGET -u admin:admin -d "body=message" http://localhost:8161/api/message/DEV.QUEUE.1?type=queue
