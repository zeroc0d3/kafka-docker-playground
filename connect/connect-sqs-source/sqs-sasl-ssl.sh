#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

${DIR}/../../environment/sasl-ssl/start.sh "${PWD}/docker-compose.sasl-ssl.yml"


QUEUE_NAME="sqs-source-connector-demo-ssl"
AWS_REGION=$(aws configure get region)
QUEUE_URL_RAW=$(aws sqs create-queue --queue-name $QUEUE_NAME | jq .QueueUrl)
AWS_ACCOUNT_NUMBER=$(echo "$QUEUE_URL_RAW" | cut -d "/" -f 4)
# https://docs.amazonaws.cn/sdk-for-net/v3/developer-guide/how-to/sqs/QueueURL.html
# https://{REGION_ENDPOINT}/queue.|api-domain|/{YOUR_ACCOUNT_NUMBER}/{YOUR_QUEUE_NAME}
QUEUE_URL="https://sqs.$AWS_REGION.amazonaws.com/$AWS_ACCOUNT_NUMBER/$QUEUE_NAME"

set +e
echo "Delete queue ${QUEUE_URL}"
aws sqs delete-queue --queue-url ${QUEUE_URL}
if [ $? -eq 0 ]
then
     # You must wait 60 seconds after deleting a queue before you can create another with the same name
     echo "Sleeping 60 seconds"
     sleep 60
fi
set -e

echo "Create a FIFO queue $QUEUE_NAME"
aws sqs create-queue --queue-name $QUEUE_NAME

echo "Sending messages to $QUEUE_URL"
aws sqs send-message-batch --queue-url $QUEUE_URL --entries file://send-message-batch.json

echo "########"
echo "##  SSL authentication"
echo "########"

echo "Creating SQS Source connector with SSL authentication"
docker exec -e QUEUE_URL="$QUEUE_URL" connect \
     curl -X POST \
     --cert /etc/kafka/secrets/connect.certificate.pem --key /etc/kafka/secrets/connect.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt \
     -H "Content-Type: application/json" \
     --data '{
               "name": "sqs-source-ssl",
               "config": {
                    "connector.class": "io.confluent.connect.sqs.source.SqsSourceConnector",
                    "tasks.max": "1",
                    "kafka.topic": "test-sqs-source-ssl",
                    "sqs.url": "'"$QUEUE_URL"'",
                    "confluent.license": "",
                    "name": "sqs-source-ssl",
                    "confluent.topic.bootstrap.servers": "broker:11091",
                    "confluent.topic.replication.factor": "1",
                    "confluent.topic.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "confluent.topic.ssl.keystore.password" : "confluent",
                    "confluent.topic.ssl.key.password" : "confluent",
                    "confluent.topic.ssl.truststore.location" : "/etc/kafka/secrets/kafka.connect.truststore.jks",
                    "confluent.topic.ssl.truststore.password" : "confluent",
                    "confluent.topic.ssl.keystore.type" : "JKS",
                    "confluent.topic.ssl.truststore.type" : "JKS",
                    "confluent.topic.security.protocol" : "SSL"
          }}' \
     https://localhost:8083/connectors | jq .


sleep 10

echo "Verify we have received the data in test-sqs-source-ssl topic"
docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9091 --topic test-sqs-source-ssl --from-beginning --max-messages 2 --property schema.registry.url=https://schema-registry:8085 --consumer.config /etc/kafka/secrets/client_without_interceptors.config  | tail -n 3 | head -n 2 | jq .

##FIXTHIS: need to delete connector
# C[36mconnect           |ESC[0m javax.management.InstanceAlreadyExistsException: kafka.producer:type=app-info,id=connect-worker-producer
# ESC[36mconnect           |ESC[0m        at com.sun.jmx.mbeanserver.Repository.addMBean(Repository.java:437)
# ESC[36mconnect           |ESC[0m        at com.sun.jmx.interceptor.DefaultMBeanServerInterceptor.registerWithRepository(DefaultMBeanServerInterceptor.java:1898)
# ESC[36mconnect           |ESC[0m        at com.sun.jmx.interceptor.DefaultMBeanServerInterceptor.registerDynamicMBean(DefaultMBeanServerInterceptor.java:966)
# ESC[36mconnect           |ESC[0m        at com.sun.jmx.interceptor.DefaultMBeanServerInterceptor.registerObject(DefaultMBeanServerInterceptor.java:900)
# ESC[36mconnect           |ESC[0m        at com.sun.jmx.interceptor.DefaultMBeanServerInterceptor.registerMBean(DefaultMBeanServerInterceptor.java:324)
# ESC[36mconnect           |ESC[0m        at com.sun.jmx.mbeanserver.JmxMBeanServer.registerMBean(JmxMBeanServer.java:522)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.common.utils.AppInfoParser.registerAppInfo(AppInfoParser.java:64)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.clients.producer.KafkaProducer.<init>(KafkaProducer.java:427)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.clients.producer.KafkaProducer.<init>(KafkaProducer.java:270)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.connect.runtime.Worker.buildWorkerTask(Worker.java:514)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.connect.runtime.Worker.startTask(Worker.java:459)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.connect.runtime.distributed.DistributedHerder.startTask(DistributedHerder.java:1036)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.connect.runtime.distributed.DistributedHerder.access$1600(DistributedHerder.java:117)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.connect.runtime.distributed.DistributedHerder$13.call(DistributedHerder.java:1051)
# ESC[36mconnect           |ESC[0m        at org.apache.kafka.connect.runtime.distributed.DistributedHerder$13.call(DistributedHerder.java:1047)
# ESC[36mconnect           |ESC[0m        at java.util.concurrent.FutureTask.run(FutureTask.java:266)
# ESC[36mconnect           |ESC[0m        at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
# ESC[36mconnect           |ESC[0m        at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)

docker exec connect curl -X DELETE --cert /etc/kafka/secrets/connect.certificate.pem --key /etc/kafka/secrets/connect.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt https://localhost:8083/connectors/sqs-source-ssl

echo "Delete queue ${QUEUE_URL}"
aws sqs delete-queue --queue-url ${QUEUE_URL}

echo "########"
echo "##  SASL_SSL authentication"
echo "########"

QUEUE_NAME="sqs-source-connector-demo-sasl-ssl"
QUEUE_URL_RAW=$(aws sqs create-queue --queue-name $QUEUE_NAME | jq .QueueUrl)
AWS_ACCOUNT_NUMBER=$(echo "$QUEUE_URL_RAW" | cut -d "/" -f 4)
# https://docs.amazonaws.cn/sdk-for-net/v3/developer-guide/how-to/sqs/QueueURL.html
# https://{REGION_ENDPOINT}/queue.|api-domain|/{YOUR_ACCOUNT_NUMBER}/{YOUR_QUEUE_NAME}
QUEUE_URL="https://sqs.$AWS_REGION.amazonaws.com/$AWS_ACCOUNT_NUMBER/$QUEUE_NAME"

set +e
echo "Delete queue ${QUEUE_URL}"
aws sqs delete-queue --queue-url ${QUEUE_URL}
if [ $? -eq 0 ]
then
     # You must wait 60 seconds after deleting a queue before you can create another with the same name
     echo "Sleeping 60 seconds"
     sleep 60
fi
set -e

echo "Create a FIFO queue $QUEUE_NAME"
aws sqs create-queue --queue-name $QUEUE_NAME

echo "Sending messages to $QUEUE_URL"
aws sqs send-message-batch --queue-url $QUEUE_URL --entries file://send-message-batch.json


echo "Creating SQS Source connector with SASL_SSL authentication"
docker exec -e QUEUE_URL="$QUEUE_URL" connect \
     curl -X POST \
     --cert /etc/kafka/secrets/connect.certificate.pem --key /etc/kafka/secrets/connect.key --tlsv1.2 --cacert /etc/kafka/secrets/snakeoil-ca-1.crt \
     -H "Content-Type: application/json" \
     --data '{
               "name": "sqs-source-sasl-ssl",
               "config": {
                    "connector.class": "io.confluent.connect.sqs.source.SqsSourceConnector",
                    "tasks.max": "1",
                    "kafka.topic": "test-sqs-source-sasl-ssl",
                    "sqs.url": "'"$QUEUE_URL"'",
                    "confluent.license": "",
                    "name": "sqs-source-sasl-ssl",
                    "confluent.topic.bootstrap.servers": "broker:9091",
                    "confluent.topic.replication.factor": "1",
                    "confluent.topic.ssl.keystore.location" : "/etc/kafka/secrets/kafka.connect.keystore.jks",
                    "confluent.topic.ssl.keystore.password" : "confluent",
                    "confluent.topic.ssl.key.password" : "confluent",
                    "confluent.topic.ssl.truststore.location" : "/etc/kafka/secrets/kafka.connect.truststore.jks",
                    "confluent.topic.ssl.truststore.password" : "confluent",
                    "confluent.topic.security.protocol" : "SASL_SSL",
                    "confluent.topic.sasl.mechanism": "PLAIN",
                    "confluent.topic.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required  username=\"client\" password=\"client-secret\";"
          }}' \
     https://localhost:8083/connectors | jq .

sleep 10

echo "Verify we have received the data in test-sqs-source-sasl-ssl topic"
docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9091 --topic test-sqs-source-sasl-ssl --from-beginning --max-messages 2 --property schema.registry.url=https://schema-registry:8085 --consumer.config /etc/kafka/secrets/client_without_interceptors.config  | tail -n 3 | head -n 2 | jq .

echo "Delete queue ${QUEUE_URL}"
aws sqs delete-queue --queue-url ${QUEUE_URL}