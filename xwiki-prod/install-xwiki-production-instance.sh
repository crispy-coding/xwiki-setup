#!/bin/bash

# TODO Check if other software is needed: envsubst?
# TODO Check if the the default docker-compose version from Ubuntu Repos is sufficient.
# TODO Add logic for empty email field. Use ' --register-unsafely-without-email' for certbot.

printf "\n### Checking if all required compnents are installed ...\n"
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v envsubst)" ]; then
  echo "Error: envsubst is not installed. Please install the 'gettext-base' package." >&2
  exit 1
fi

printf "\n### Asking user to provide inputs ...\n"
prompt_inputs () {
  echo "The email address is used by Let's Encrypt to warn you about your soon expiring certificates"
  echo "or when you use deprecated software. The email address will not be shared with the public."
  echo "Though I recommend to enter an email address, you can leave that field empty."
  printf "Please enter your mail address (e.g. 'me@mycompany.com'): "
  read email
  echo "Mandatory field. Let's will contact the letsencrypt server at that domain to verify that you really own it."
  printf "Please enter your domain (e.g. 'my-company.com'): "
  read domain
}

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

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  printf "\n### Copying recommended TLS parameters ...\n"
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

if [ "$1" == "test" ]; then
  printf "\n### Since this is a test, the setup is shut down and all data are deleted.\n"
  docker-compose down 2>/dev/null
  rm -rf data
else 
  echo "### Reloading nginx ..."
  docker-compose exec nginx nginx -s reload
  echo "### Starting the docker-compose setup ..."
  docker-compose up -d  
fi
