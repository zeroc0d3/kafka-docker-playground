# LDAP Authorizer with SASL/SCRAM-SHA-256

## Description

This is a deployment with no SSL encryption, SASL_PLAINTEXT as the security protocol for the Kafka broker and Kafka clients with SASL/SCRAM-SHA-256 as the SASL mechanism:

* 1 zookeeper
* 1 broker
* 1 connect
* 1 schema-registry
* 1 control-center

The goal is to test [LDAP authorizer](https://docs.confluent.io/current/security/ldap-authorizer/quickstart.html#using-the-ldap-auth-long) in this config.

## How to run
  
Simply run:

```
$ ./start.sh
```

## Credits

Largely inspired by [Dabz/kafka-security-playbook](https://github.com/Dabz/kafka-security-playbook/tree/master/ldap)