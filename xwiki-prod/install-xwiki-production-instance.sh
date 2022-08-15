#!/bin/bash

# TODO Check if other software is needed: envsubst?
# TODO Check if the the default docker-compose version from Ubuntu Repos is suffucient.

set -e

testCert=""
if [ "$1" == "test" ]; then testCert="--test-cert"; fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

printf "Please enter your mail address: "
read email
printf "Pleaser enter your domain: "
read domain
export domain
# Docker container name and port are static.

mkdir -p data/nginx/conf.d
envsubst '$domain' < config/nginx/app.conf_template > data/nginx/conf.d/app.conf

domains=($domain)
rsa_key_size=4096
data_path="./data/certbot"

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi


if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Copying recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  cp "config/certbot/options-ssl-nginx.conf" "$data_path/conf/options-ssl-nginx.conf"
  cp "config/certbot/ssl-dhparams.pem" "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo


echo "### Starting mariadb, xwiki and nginx ..."
docker-compose up --force-recreate -d nginx xwiki mariadb
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo

echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -n -w /var/www/certbot \
    $email_arg \
    $domain_args \
    "$testCert" \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload

echo "### Starting the docker-compose setup ..."
docker-compose up -d
