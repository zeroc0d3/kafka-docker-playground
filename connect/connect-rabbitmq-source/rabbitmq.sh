#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

echo "Send message to RabbitMQ in myqueue"
docker exec rabbitmq_producer bash -c "python /producer.py myqueue 5"

echo "Creating RabbitMQ Source connector"
docker exec connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
               "name": "RabbitMQSourceConnector2",
               "config": {
                  "connector.class" : "io.confluent.connect.rabbitmq.RabbitMQSourceConnector",
                  "tasks.max" : "1",
                  "kafka.topic" : "rabbitmq",
                  "rabbitmq.queue" : "myqueue",
                  "rabbitmq.host" : "rabbitmq",
                  "rabbitmq.username" : "myuser",
                  "rabbitmq.password" : "mypassword"
          }}' \
     http://localhost:8083/connectors | jq .


sleep 5

echo "Verify we have received the data in rabbitmq topic"
docker exec schema-registry kafka-avro-console-consumer -bootstrap-server broker:9092 --topic rabbitmq --from-beginning --max-messages 5

#echo "Consume messages in RabbitMQ"
#docker exec -it rabbitmq_consumer bash -c "python /consumer.py myqueue"