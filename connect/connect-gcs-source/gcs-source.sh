#!/bin/bash
set -e

verify_installed()
{
  local cmd="$1"
  if [[ $(type $cmd 2>&1) =~ "not found" ]]; then
    echo -e "\nERROR: This script requires '$cmd'. Please install '$cmd' and run again.\n"
    exit 1
  fi
}
verify_installed "gcloud"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BUCKET_NAME=${1:-test-gcs-playground}

KEYFILE="${DIR}/keyfile.json"
if [ ! -f ${KEYFILE} ]
then
     echo "ERROR: the file ${KEYFILE} file is not present!"
     exit 1
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


echo "Removing existing objects in GCS, if applicable"
set +e
gsutil rm -r gs://$BUCKET_NAME/topics/gcs_topic
set -e


##########################
## SINK
##########################

echo "Sending messages to topic gcs_topic"
seq -f "{\"f1\": \"value%g\"}" 10 | docker exec -i schema-registry kafka-avro-console-producer --broker-list broker:9092 --topic gcs_topic --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"f1","type":"string"}]}'


echo "Creating GCS Sink connector"
docker exec -e BUCKET_NAME="$BUCKET_NAME" connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
               "name": "GCSSinkConnector",
               "config": {
                    "connector.class": "io.confluent.connect.gcs.GcsSinkConnector",
                    "tasks.max" : "1",
                    "topics" : "gcs_topic",
                    "gcs.bucket.name" : "'"$BUCKET_NAME"'",
                    "gcs.part.size": "5242880",
                    "flush.size": "3",
                    "gcs.credentials.path": "/root/keyfiles/keyfile.json",
                    "storage.class": "io.confluent.connect.gcs.storage.GcsStorage",
                    "format.class": "io.confluent.connect.gcs.format.avro.AvroFormat",
                    "partitioner.class": "io.confluent.connect.storage.partitioner.DefaultPartitioner",
                    "schema.compatibility": "NONE",
                    "confluent.topic.bootstrap.servers": "broker:9092",
                    "confluent.topic.replication.factor": "1"
          }}' \
     http://localhost:8083/connectors | jq .

sleep 10

echo "Doing gsutil authentication"
gcloud auth activate-service-account --key-file ${KEYFILE}

echo "Listing objects of in GCS"
gsutil ls gs://$BUCKET_NAME/topics/gcs_topic/partition=0/

echo "Getting one of the avro files locally and displaying content with avro-tools"
gsutil cp gs://$BUCKET_NAME/topics/gcs_topic/partition=0/gcs_topic+0+0000000000.avro /tmp/

# brew install avro-tools
avro-tools tojson /tmp/gcs_topic+0+0000000000.avro


##########################
## SOURCE
##########################
echo "Creating GCS Source connector"
docker exec -e BUCKET_NAME="$BUCKET_NAME" connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
               "name": "GCSSourceConnector",
               "config": {
                    "connector.class": "io.confluent.connect.gcs.GcsSourceConnector",
                    "gcs.bucket.name" : "'"$BUCKET_NAME"'",
                    "gcs.credentials.path" : "/root/keyfiles/keyfile.json",
                    "format.class": "io.confluent.connect.gcs.format.avro.AvroFormat",
                    "tasks.max" : "1",
                    "confluent.topic.bootstrap.servers" : "broker:9092",
                    "confluent.topic.replication.factor" : "1",
                    "transforms" : "AddPrefix",
                    "transforms.AddPrefix.type" : "org.apache.kafka.connect.transforms.RegexRouter",
                    "transforms.AddPrefix.regex" : ".*",
                    "transforms.AddPrefix.replacement" : "copy_of_$0"
          }}' \
     http://localhost:8083/connectors | jq .

sleep 10

echo "Verify messages are in topic copy_of_gcs_topic"
docker exec schema-registry kafka-avro-console-consumer -bootstrap-server broker:9092 --topic copy_of_gcs_topic --from-beginning --max-messages 9
