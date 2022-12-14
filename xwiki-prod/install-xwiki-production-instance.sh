#!/bin/bash

printf "\n### Checking if all required compnents are installed ...\n"
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

IFS='.' read -r -a dockerComposeVersion <<< $(docker-compose version --short)
if [ "${dockerComposeVersion[0]}" == "1" ] && [ "${dockerComposeVersion[1]}" -lt "29" ]; then
  echo "Your current docker-compose version is $(docker-compose version --short) but it should be at least 1.29. Please update."
  exit 1
fi

if ! [ -x "$(command -v envsubst)" ]; then
  echo "Error: envsubst is not installed. Please install the 'gettext-base' package." >&2
  exit 1
fi

printf "\n### Checking if data of old deployment is contained within current folder ...\n"
if [ -d "data" ] || [ -f ".env" ] ; then
  read -p  "Existing 'data' directory and/or '.env' file with database passwords found in current folder. There seems to be an old deployment. \
Do you want to delete all its persistent data and set up a new, empty XWiki instance? (y/N) " deleteOldData

  if [ "$deleteOldData" == "Y" ] || [ "$deleteOldData" == "y" ]; then
    echo "Deleting data of old deployment ..."
    rm -rf data .env
  else
    echo "The old deployment data was not deleted and the script is aborted."
    exit 
  fi
fi

prompt_inputs () {
  printf "\nThe email address is used by Let's Encrypt to warn you about your soon expiring certificates\n"
  echo "or when you use deprecated software. The email address will not be shared with the public."
  echo "Though it is recommended to enter an email address, you can leave that field empty."
  printf "Please enter your mail address (e.g. 'me@mycompany.com'): "
  read email
  printf "\nThis is a mandatory field. Certbot will let the Let's Encrypt server contact this domain to verify that you really own it.\n"
  printf "Please enter your domain (e.g. 'my-company.com'): "
  read domain
}

printf "\n### Preparing email address and domain inputs ...\n"
# If test-mode is enabled the inputs are read from a persistent input file. If that does not exist, the inputs
# are prompted and stored in such a file. This reduces the repeating manual input of the user during development/testing.
if [ "$1" == "test" ]; then
  testCert="--test-cert"
  if [ -f "config/test-inputs.txt" ]; then
    echo "Existing inputs found in config/test-inputs.txt. No manual input entering required."
    readarray -t inputs < config/test-inputs.txt
    email="${inputs[0]}"
    domain="${inputs[1]}"
  else
    prompt_inputs
    echo $email > config/test-inputs.txt
    echo $domain >> config/test-inputs.txt
  fi
else
  prompt_inputs
fi


mkdir -p data/nginx/conf.d
export domain
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

printf "\n### Preparing recommended TLS parameters ...\n"
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  mkdir -p "$data_path/conf"
  cp "config/certbot/options-ssl-nginx.conf" "$data_path/conf/options-ssl-nginx.conf"
  cp "config/certbot/ssl-dhparams.pem" "$data_path/conf/ssl-dhparams.pem"
fi

printf "\n### Preparing passwords for mariadb access ...\n"
if [ ! -e ".env" ]; then
  echo "Generating new passwords to '.env' file ..."
  echo "DB_USER_PASSWORD=\"$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c25)\"" > .env
  echo "DB_ROOT_PASSWORD=\"$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c25)\"" >> .env
fi

printf "\n### Creating dummy certificate for $domains ...\n"
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot

printf "\n### Starting mariadb, xwiki and nginx ...\n"
docker-compose up --force-recreate -d nginx xwiki mariadb

printf "\n### Deleting dummy certificate for $domains ...\n"
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot

printf "\n### Requesting Let's Encrypt certificate for $domains ...\n"
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

if [ "$1" == "test" ]; then
  printf "\n### Since this is a test, the setup is shut down and all data are deleted.\n"
  docker-compose down 2>/dev/null
  rm -rf data .env
else 
  echo "Reloading nginx ..."
  docker-compose exec nginx nginx -s reload
  echo "Starting the docker-compose setup ..."
  docker-compose up -d  
  printf "\nYou can find the mariadb passwords in the '.env' file.\n"
fi
