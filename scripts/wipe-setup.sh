#!/bin/bash

. env.sh

cd "$NGINX_CERTBOT_DIR"
docker-compose down
printf "\n### Removing all persistent data of nginx-certbot\n\n"
rm config/app.conf
rm -rf data

cd "$XWIKI_DIR"
docker-compose down
printf "\n### Removing all persistent data of xwiki.\n\n"
rm -rf data
