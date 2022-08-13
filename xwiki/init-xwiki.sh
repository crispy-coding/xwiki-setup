#!/bin/bash

chmod 755 config/init.sql
docker-compose up -d
docker-compose restart db
