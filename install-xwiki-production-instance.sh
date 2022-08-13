#!/bin/bash

cd nginx-certbot
chmod +x init-letsencrypt.sh
. init-letsencrypt.sh


cd ../xwiki
chmod +x init-xwiki.sh
. init-xwiki.sh
