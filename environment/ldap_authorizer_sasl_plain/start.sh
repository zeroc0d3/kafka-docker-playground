#!/bin/bash

verify_installed()
{
  local cmd="$1"
  if [[ $(type $cmd 2>&1) =~ "not found" ]]; then
    echo -e "\nERROR: This script requires '$cmd'. Please install '$cmd' and run again.\n"
    exit 1
  fi
}
verify_installed "docker-compose"

DOCKER_COMPOSE_FILE_OVERRIDE=$1
if [ -f "${DOCKER_COMPOSE_FILE_OVERRIDE}" ]
then
  echo "Using ${DOCKER_COMPOSE_FILE_OVERRIDE}"
  docker-compose -f ../../environment/ldap_authorizer_sasl_plain/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} down -v
  docker-compose -f ../../environment/ldap_authorizer_sasl_plain/docker-compose.yml -f ${DOCKER_COMPOSE_FILE_OVERRIDE} up -d
else
  docker-compose down -v
  docker-compose up -d
fi

../../WaitForConnectAndControlCenter.sh

# Not required as User:broker is super user
# SET ACLs
# Authorize broker user kafka for cluster operations. Note that the example uses user-principal based ACL for brokers, but brokers may also be configured to use group-based ACLs.
#docker exec broker kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 --add --cluster --operation=All --allow-principal=User:broker

# Test LDAP group-based authorization
# https://docs.confluent.io/current/security/ldap-authorizer/quickstart.html#test-ldap-group-based-authorization
echo "Create topic testtopic"
docker exec broker kafka-topics --create --topic testtopic --partitions 10 --replication-factor 1 --zookeeper zookeeper:2181

echo "Run console producer without authorizing user alice: SHOULD FAIL"
docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic testtopic --producer.config /service/kafka/users/alice.properties << EOF
message Alice
EOF

echo "Authorize group Group:Kafka Developers and rerun producer for alice: SHOULD BE SUCCESS"
docker exec broker kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 --add --topic=testtopic --producer --allow-principal="Group:Kafka Developers"

sleep 1

docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic testtopic --producer.config /service/kafka/users/alice.properties << EOF
message Alice
EOF

echo "Run console consumer without access to consumer group: SHOULD FAIL"
# Consume should fail authorization since neither user alice nor the group Kafka Developers that alice belongs to has authorization to consume using the group test-consumer-group
docker exec broker kafka-console-consumer --bootstrap-server broker:9092 --topic testtopic --from-beginning --group test-consumer-group --consumer.config /service/kafka/users/alice.properties --max-messages 1

echo "Authorize group and rerun consumer"
docker exec broker kafka-acls --authorizer-properties zookeeper.connect=zookeeper:2181 --add --topic=testtopic --group test-consumer-group --allow-principal="Group:Kafka Developers"
docker exec broker kafka-console-consumer --bootstrap-server broker:9092 --topic testtopic --from-beginning --group test-consumer-group --consumer.config /service/kafka/users/alice.properties --max-messages 1

echo "Run console producer with authorized user barnie (barnie is in group): SHOULD BE SUCCESS"
docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic testtopic --producer.config /service/kafka/users/barnie.properties << EOF
message Barnie
EOF

echo "Run console producer without authorizing user (charlie is NOT in group): SHOULD FAIL"
docker exec -i broker kafka-console-producer --broker-list broker:9092 --topic testtopic --producer.config /service/kafka/users/charlie.properties << EOF
message Charlie
EOF

echo "Listing ACLs"
docker exec broker kafka-acls --bootstrap-server broker:9092 --list --command-config /service/kafka/users/kafka.properties
