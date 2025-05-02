# Base Image UBUNTU 20.04
FROM ubuntu:20.04

LABEL mantainer="Rafael <rafael@booug.com>"

# Working directory as root
USER root
WORKDIR "/root"

# No prompts please
ENV DEBIAN_FRONTEND=noninteractive

# Fixes some weird terminal issues such as broken clear / CTRL+L
ENV TERM=linux

## Wordpress Conf
COPY ./wordpress/wp-config-docker.php /tmp/wp-config-docker.php

# Perform Installations
COPY ./docker-runs.sh /root/docker-runs.sh
RUN chmod +x "/root/docker-runs.sh"
RUN /root/docker-runs.sh
RUN mkdir -p /var/www/scripts

# Copying neccessary files

## NGINX Conf
COPY ./nginx/app.conf /etc/nginx/conf.d/app.conf

## PHP Conf
COPY ./php/php-fpm.conf /etc/php/8.4/fpm/php-fpm.conf

## Supervisor
COPY ./supervisord/supervisord.conf /etc/supervisord.conf

## Docker scripts
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x "/usr/local/bin/docker-entrypoint.sh"

WORKDIR "/var/www/html"

ENTRYPOINT docker-entrypoint.sh