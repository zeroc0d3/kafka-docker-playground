#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [ ! -f ${DIR}/mysql-connector-java-5.1.45.jar ]
then
     echo "Downloading mysql-connector-java-5.1.45.jar"
     wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.45/mysql-connector-java-5.1.45.jar
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


echo "Describing the application table in DB 'db':"
docker exec mysql bash -c "mysql --user=root --password=password --database=db -e 'describe application'"

echo "Show content of application table:"
docker exec mysql bash -c "mysql --user=root --password=password --database=db -e 'select * from application'"

echo "Adding an element to the table"
docker exec mysql mysql --user=root --password=password --database=db -e "
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
docker exec mysql bash -c "mysql --user=root --password=password --database=db -e 'select * from application'"

echo "Creating MySQL source connector"
docker exec connect \
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
docker exec schema-registry kafka-avro-console-consumer -bootstrap-server broker:9092 --topic mysql-application --from-beginning --max-messages 2


