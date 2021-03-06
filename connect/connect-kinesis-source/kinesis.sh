#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


set +e
echo "Delete the stream"
aws kinesis delete-stream --stream-name my_kinesis_stream
set -e

sleep 5

echo "Create a Kinesis stream my_kinesis_stream"
aws kinesis create-stream --stream-name my_kinesis_stream --shard-count 1

echo "Sleep 30 seconds to let the Kinesis stream being fully started"
sleep 30

echo "Insert records in Kinesis stream"
# The example shows that a record containing partition key 123 and data "test-message-1" is inserted into my_kinesis_stream.
aws kinesis put-record --stream-name my_kinesis_stream --partition-key 123 --data test-message-1


echo "Creating Kinesis Source connector"
docker exec connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
        "name": "kinesis-source",
        "config": {
               "connector.class":"io.confluent.connect.kinesis.KinesisSourceConnector",
               "tasks.max": "1",
               "kafka.topic": "kinesis_topic",
               "kinesis.region": "US_EAST_1",
               "kinesis.stream": "my_kinesis_stream",
               "confluent.license": "",
               "name": "kinesis-source",
               "confluent.topic.bootstrap.servers": "broker:9092",
               "confluent.topic.replication.factor": "1"
          }}' \
     http://localhost:8083/connectors | jq .

echo "Verify we have received the data in kinesis_topic topic"
docker exec broker kafka-console-consumer --bootstrap-server broker:9092 --topic kinesis_topic --from-beginning --max-messages 1

echo "Delete the stream"
aws kinesis delete-stream --stream-name my_kinesis_stream