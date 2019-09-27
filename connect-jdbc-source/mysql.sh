#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
BUCKET_NAME=${1:-kafka-docker-playground} 

${DIR}/reset-cluster.sh

echo "Describing the application table in DB 'db':"
docker-compose exec mysql bash -c "mysql --user=root --password=password --database=db -e 'describe application'"

echo "Show content of application table:"
docker-compose exec mysql bash -c "mysql --user=root --password=password --database=db -e 'select * from application'"

echo "Adding an element to the table"
docker-compose exec mysql mysql --user=root --password=password --database=db -e "
INSERT INTO application (   \
  id,   \
  name, \
  team_email,   \
  last_modified \
) VALUES (  \
  2,    \
  'another',  \
  'another@apache.org',   \
  NOW() \
); "

echo "Show content of application table:"
docker-compose exec mysql bash -c "mysql --user=root --password=password --database=db -e 'select * from application'"

echo "Creating MySQL source connector"
docker-compose exec connect \
     curl -X POST \
     -H "Content-Type: application/json" \
     --data '{
               "name": "mysql-source",
               "config": {
                    "connector.class":"io.confluent.connect.jdbc.JdbcSourceConnector",
                    "tasks.max":"10",
                    "connection.url":"jdbc:mysql://mysql:3306/db?user=user&password=password&useSSL=false",
                    "table.whitelist":"application",
                    "mode":"timestamp+incrementing",
                    "timestamp.column.name":"last_modified",
                    "incrementing.column.name":"id",
                    "topic.prefix":"mysql-"
          }}' \
     http://localhost:8083/connectors | jq .

sleep 5

echo "Verifying topic mysql-application"
docker-compose exec schema-registry kafka-avro-console-consumer -bootstrap-server broker:9092 --topic mysql-application --from-beginning --max-messages 2

