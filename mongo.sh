#!/bin/bash

DOMAIN="privmx-test-mongo.westeurope.cloudapp.azure.com"
EMAIL="sysadmin@simplito.com"

sudo apt update
sudo apt upgrade -y
sudo apt install --no-install-recommends -y docker.io docker-compose certbot pwgen

echo 'version: "3.1"

services:

  mongo:
    image: mongo:6.0.8
    restart: always
    ports:
      - 27017:27017
    network_mode: bridge
    extra_hosts:
      - privmx-test-mongo.westeurope.cloudapp.azure.com:127.0.0.1
    volumes:
      - /srv/mongo/data:/data/db
      - /srv/mongo/cert:/data/cert
    entrypoint: [ "/usr/bin/mongod", "--bind_ip_all", "--replSet", "pcapp", "--tlsMode", "requireTLS", "--tlsCertificateKeyFile", "/data/cert/mongo.pem" ]' > docker-compose.yml

PASSWORD_ROOT=$(pwgen -snc 16 1)
PASSWORD_USER=$(pwgen -snc 16 1)

sudo certbot certonly --standalone --preferred-challenges http --non-interactive --agree-tos --email $EMAIL -d $DOMAIN

[ ! -d "/srv/mongo" ] && sudo mkdir /srv/mongo || echo "Directory /srv/mongo exists."
sudo cp docker-compose.yml /srv/mongo/docker-compose.yml
sudo ln -s /etc/letsencrypt/live/$DOMAIN /srv/mongo/cert
sudo bash -c "cat /srv/mongo/cert/fullchain.pem /srv/mongo/cert/privkey.pem > /srv/mongo/cert/mongo.pem"
sudo bash -c "openssl rand -base64 756 >> /srv/mongo/cert/rs-key.yaml"
sudo chmod 400 /srv/mongo/cert/rs-key.yaml


export DOMAIN=$DOMAIN
cd /srv/mongo
sudo docker-compose up -d
sleep 3
sudo docker-compose exec mongo mongosh --tls --tlsAllowInvalidCertificates admin --eval 'rs.initiate({_id : "pcapp", members: [{_id: 0, host: "'"$DOMAIN"':27017"}]})'
sudo docker-compose exec mongo mongosh --tls --tlsAllowInvalidCertificates admin --eval 'db.createUser( { user: "simpliadmin", pwd: "'"$PASSWORD_ROOT"'", roles: [ { role: "userAdminAnyDatabase", db: "admin" }, { role: "readWriteAnyDatabase", db: "admin" }, { role: "dbAdminAnyDatabase", db: "admin" }, { role: "backup", db: "admin" }, { role: "clusterAdmin", db: "admin" }, { role: "restore", db: "admin" } ]})'
sudo docker-compose exec mongo mongosh --tls --tlsAllowInvalidCertificates admin --eval 'db.createUser({user: "pcappadmin", pwd: "'"$PASSWORD_USER"'", roles: [{ role: "readWriteAnyDatabase", db: "admin" },{ role: "dbAdminAnyDatabase", db: "admin" }]})'
sudo docker-compose down

sudo echo $PASSWORD_USER > pass_user
sudo echo $PASSWORD_ROOT > pass_root

# edit docker-compose.yml to replace entrypoint to:
sudo echo 'version: "3.1"

services:

  mongo:
    image: mongo:6.0.8
    restart: always
    ports:
      - 27017:27017
    network_mode: bridge
    extra_hosts:
      - privmx-test-mongo.westeurope.cloudapp.azure.com:127.0.0.1
    volumes:
      - /srv/mongo/data:/data/db
      - /srv/mongo/cert:/data/cert
    entrypoint: [ "/usr/bin/mongod", "--auth", "--bind_ip_all", "--replSet", "pcapp", "--tlsMode", "requireTLS", "--tlsCertificateKeyFile", "/data/cert/mongo.pem", "--keyFile", "/data/cert/rs-key.yaml" ]' > docker-compose.yml

docker-compose up -d
