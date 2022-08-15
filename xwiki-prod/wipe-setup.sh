#!/bin/bash

docker-compose down
printf "\n### Removing all persistent data of nginx-certbot\n\n"
rm -rf config/app.conf data
