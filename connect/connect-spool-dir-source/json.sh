#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

mkdir -p ${DIR}/data/input
mkdir -p ${DIR}/data/error
mkdir -p ${DIR}/data/finished

if [ ! -f "${DIR}/data/input/json-spooldir-source.json" ]
then
     echo "Generating data"
     curl "https://api.mockaroo.com/api/17c84440?count=500&key=25fd9c80" > "${DIR}/data/input/json-spooldir-source.json"
fi

echo "Creating JSON Spool Dir Source connector"
docker exec connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
               "name": "JsonSpoolDir",
               "config": {
                    "tasks.max": "1",
                    "connector.class": "com.github.jcustenborder.kafka.connect.spooldir.SpoolDirJsonSourceConnector",
                    "input.path": "/root/data/input",
                    "input.file.pattern": "json-spooldir-source.json",
                    "error.path": "/root/data/error",
                    "finished.path": "/root/data/finished",
                    "halt.on.error": "false",
                    "topic": "spooldir-json-topic",
                    "schema.generation.enabled": "true"
          }}' \
     http://localhost:8083/connectors | jq .


sleep 5

echo "Verify we have received the data in spooldir-json-topic topic"
docker exec schema-registry kafka-avro-console-consumer -bootstrap-server broker:9092 --topic spooldir-json-topic --property schema.registry.url=http://schema-registry:8081 --from-beginning --max-messages 10