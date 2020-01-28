#!/bin/bash

cp /myCA.pem /mnt/etc/ssl/certs
nsenter --target 1 --mount update-ca-certificates
nsenter --target 1 --mount systemctl restart docker
