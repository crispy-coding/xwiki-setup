#!/bin/bash

. install-xwiki-production-instance.sh test || printf "\nWarning: Test failed.\n"
docker-compose down 2>/dev/null
rm -rf data
